# 🔄 Contabo to OVH Migration Guide
## Step-by-Step Bitcoin Node Migration for Medampudi Family

### 📊 Migration Overview
**Source**: Contabo server with synced Bitcoin node
**Target**: OVH dedicated server with Ubuntu 24.04
**Goal**: Migrate without losing blockchain sync (save 3-5 days)

### ⏱️ Estimated Timeline
- **Server Setup**: 2-3 hours
- **Data Migration**: 4-8 hours (depending on connection)
- **Service Setup**: 1-2 hours
- **Total**: 8-12 hours over 1-2 days

---

## Phase 1: Prepare OVH Server (2-3 hours)

### Step 1.1: Initial Server Access
```bash
# SSH into your OVH dedicated server as ubuntu user
ssh ubuntu@YOUR_OVH_IP

# OVH Ubuntu servers come with 'ubuntu' user pre-configured
# No need to create additional admin user
whoami  # Should show: ubuntu
sudo -l # Should show sudo permissions
```

### Step 1.2: Run Automated Setup Script
```bash
# Download and run the automated setup
wget https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-automated-setup.sh
chmod +x ovh-automated-setup.sh

# Edit configuration variables first!
nano ovh-automated-setup.sh
# Change:
# - DOMAIN_NAME
# - BTCPAY_DOMAIN  
# - EMAIL
# - All passwords
# - TAILSCALE_AUTHKEY (get from https://login.tailscale.com/admin/settings/keys)

# Run the setup script
./ovh-automated-setup.sh
```

### Step 1.3: Configure Tailscale
```bash
# If auto-setup didn't work, configure manually
sudo tailscale up --hostname="medampudi-bitcoin-node"

# Note your Tailscale IP for family access
tailscale ip -4
```

### Step 1.4: Setup Cloudflare Tunnel
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create tunnel for your domain
cloudflared tunnel create medampudi-bitcoin

# Note the Tunnel ID and create config
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

**Cloudflare Config** (`/etc/cloudflared/config.yml`):
```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/admin/.cloudflared/YOUR_TUNNEL_ID.json

originRequest:
  noTLSVerify: true

ingress:
  # Only BTCPay Server is publicly exposed
  - hostname: pay.your-domain.com
    service: http://localhost:80
    
  # All other services via Tailscale only
  - service: http_status:404
```

```bash
# Copy credentials and start service
sudo cp ~/.cloudflared/*.json /etc/cloudflared/
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

---

## Phase 2: Data Migration from Contabo (4-8 hours)

### Step 2.1: Prepare Contabo Server for Backup
```bash
# SSH into your Contabo server
ssh admin@YOUR_CONTABO_IP

# Stop Bitcoin service to ensure clean backup
cd /opt/bitcoin
docker compose stop bitcoind

# Create migration backup directory
mkdir -p /tmp/bitcoin-migration
cd /opt/bitcoin
```

### Step 2.2: Create Blockchain Data Backup
```bash
# This is the CRITICAL backup - saves 3-5 days of sync time
echo "🔄 Creating Bitcoin blockchain backup..."

# Backup blocks and chainstate (the essential data)
sudo tar -czf /tmp/bitcoin-migration/bitcoin_blockchain.tar.gz \
    -C data/bitcoin blocks chainstate

# Backup wallet if exists
if [ -d "data/bitcoin/wallet" ]; then
    sudo tar -czf /tmp/bitcoin-migration/bitcoin_wallet.tar.gz \
        -C data/bitcoin wallet
    echo "✅ Wallet backup created"
fi

# Backup any custom configurations
tar -czf /tmp/bitcoin-migration/bitcoin_configs.tar.gz configs/

echo "✅ Blockchain backup completed"
ls -lh /tmp/bitcoin-migration/
```

### Step 2.3: Transfer Data to OVH Server
```bash
# From Contabo server, transfer to OVH
rsync -avz --progress /tmp/bitcoin-migration/ ubuntu@YOUR_OVH_IP:/opt/bitcoin/migration/

# This will take 4-8 hours depending on your connection
# Monitor progress and ensure transfer completes
```

### Step 2.4: Restore Data on OVH Server
```bash
# SSH into OVH server
ssh ubuntu@YOUR_OVH_IP
cd /opt/bitcoin

# Ensure Docker volumes are created
docker compose up --no-start

# Stop any running Bitcoin service
docker compose stop bitcoind || true

# Restore blockchain data to Docker volume
echo "📂 Restoring Bitcoin blockchain data..."
sudo docker run --rm \
    -v bitcoin_data:/data \
    -v /opt/bitcoin/migration:/backup \
    alpine sh -c "cd /data && tar -xzf /backup/bitcoin_blockchain.tar.gz"

# Restore wallet if exists
if [ -f "/opt/bitcoin/migration/bitcoin_wallet.tar.gz" ]; then
    echo "📂 Restoring Bitcoin wallet..."
    sudo docker run --rm \
        -v bitcoin_data:/data \
        -v /opt/bitcoin/migration:/backup \
        alpine sh -c "cd /data && tar -xzf /backup/bitcoin_wallet.tar.gz"
fi

# Set proper ownership
sudo docker run --rm \
    -v bitcoin_data:/data \
    alpine chown -R 1000:1000 /data

echo "✅ Bitcoin data restored!"
```

---

## Phase 3: Start Bitcoin Services (1-2 hours)

### Step 3.1: Start Bitcoin Node
```bash
cd /opt/bitcoin

# Start Bitcoin Core first
docker compose up -d bitcoind

# Monitor Bitcoin startup and sync progress
docker logs -f bitcoind

# Check status (should resume from last block)
./scripts/bitcoin-status.sh
```

### Step 3.2: Wait for Bitcoin to Fully Sync
```bash
# Bitcoin should resume from where Contabo left off
# Monitor sync progress
watch -n 30 './scripts/bitcoin-status.sh'

# Wait until sync is 100% before starting other services
# This should be quick if migration worked correctly
```

### Step 3.3: Start Database Services
```bash
# Once Bitcoin is 80%+ synced, start databases
docker compose up -d postgres mempool-db

# Check database status
docker ps | grep -E "postgres|mempool-db"
```

### Step 3.4: Start Fulcrum Electrum Server
```bash
# Wait until Bitcoin is 95%+ synced
# Start Fulcrum (this will take 2-4 hours for initial index)
docker compose up -d fulcrum

# Monitor Fulcrum indexing progress
docker logs -f fulcrum
```

### Step 3.5: Start Remaining Services
```bash
# Start Mempool and Block Explorer
docker compose up -d mempool-api mempool-web btc-rpc-explorer

# Check all services are running
docker ps
```

---

## Phase 4: BTCPay Server Setup (1 hour)

### Step 4.1: Install BTCPay Server
```bash
cd /opt/bitcoin
mkdir -p btcpay && cd btcpay

# Clone BTCPay Docker setup
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

# Create BTCPay environment file
cat > btcpay.env << EOF
export BTCPAY_HOST="pay.your-domain.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="bitcoin-nobitcoind;opt-add-thunderhub"
export BTCPAY_ENABLE_SSH=false
export BTCPAY_EXTERNAL_BITCOIND_HOST="172.25.0.10"
export BTCPAY_EXTERNAL_BITCOIND_RPCPORT="8332"
export BTCPAY_EXTERNAL_BITCOIND_RPCUSER="$BITCOIN_RPC_USER"
export BTCPAY_EXTERNAL_BITCOIND_RPCPASSWORD="$BITCOIN_RPC_PASS"
EOF

# Install BTCPay
source btcpay.env
./btcpay-setup.sh -i
```

### Step 4.2: Configure BTCPay for External Bitcoin Node
```bash
# BTCPay will connect to your Docker Bitcoin node
# Verify connection in BTCPay admin panel after setup
```

---

## Phase 5: Security Hardening (30 minutes)

### Step 5.1: Restrict SSH to Tailscale Only
```bash
# Get your Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)

# Update SSH configuration
sudo nano /etc/ssh/sshd_config.d/99-custom.conf

# Add this line:
# ListenAddress YOUR_TAILSCALE_IP
# ListenAddress 127.0.0.1

# Restart SSH
sudo systemctl restart ssh
```

### Step 5.2: Update Firewall Rules
```bash
# Remove public SSH access (once Tailscale is working)
sudo ufw delete allow 22/tcp
sudo ufw reload

# Test Tailscale SSH access from another device before disconnecting!
```

### Step 5.3: Configure DNS in Cloudflare
In your Cloudflare dashboard:
1. Go to DNS settings
2. Add CNAME record: `pay` → `YOUR_TUNNEL_ID.cfargotunnel.com`
3. Enable proxy (orange cloud)

---

## Phase 6: Family Setup and Testing (30 minutes)

### Step 6.1: Test All Services
```bash
cd /opt/bitcoin

# Check complete system status
./scripts/bitcoin-status.sh

# Get family access information
./scripts/family-access.sh
```

### Step 6.2: Create Family Tailscale Access
```bash
# Invite family members to Tailscale
# Go to https://login.tailscale.com/admin/settings/users
# Invite: apoorva@email.com, ravi@email.com, etc.

# They'll install Tailscale app and can access services
```

### Step 6.3: Test Mobile Wallet Connections
```bash
# Family members can now connect mobile wallets:
# Electrum: TAILSCALE_IP:50001
# Lightning: TAILSCALE_IP:9735
# BTCPay: https://pay.your-domain.com
```

---

## Phase 7: Cleanup Contabo Server (15 minutes)

### Step 7.1: Verify OVH Setup is Working
```bash
# From OVH server, verify all services
./scripts/bitcoin-status.sh

# Test family access URLs work
./scripts/family-access.sh

# Check BTCPay Server is accessible via domain
```

### Step 7.2: Backup Contabo Configuration (Optional)
```bash
# SSH to Contabo one final time
ssh admin@YOUR_CONTABO_IP

# Create final configuration backup
tar -czf ~/contabo-final-backup.tar.gz /opt/bitcoin/

# Download to local machine for safety
scp admin@YOUR_CONTABO_IP:~/contabo-final-backup.tar.gz ./
```

### Step 7.3: Cancel Contabo Services
1. ✅ Verify OVH is working perfectly for 48+ hours
2. ✅ All family members can access services
3. ✅ BTCPay Server is functioning
4. ✅ Lightning Network is operational
5. ❗ Cancel Contabo subscription

---

## 🔧 Migration Verification Checklist

### ✅ Critical Services Working
- [ ] Bitcoin Core running and synced (100%)
- [ ] Fulcrum Electrum server indexed and serving
- [ ] BTCPay Server accessible via domain
- [ ] Lightning Network operational
- [ ] Mempool explorer working
- [ ] BTC RPC explorer working
- [ ] All Docker containers healthy

### ✅ Network Access Working  
- [ ] Tailscale VPN connected from multiple devices
- [ ] Family members can access services via Tailscale
- [ ] SSH access via Tailscale only
- [ ] BTCPay Server public access via Cloudflare
- [ ] Mobile wallets can connect to Electrum server

### ✅ Data Integrity Verified
- [ ] Bitcoin blockchain fully synced (compare block height)
- [ ] Wallet balance correct (if migrated)
- [ ] Lightning channels operational (if migrated)
- [ ] Transaction history accessible

### ✅ Security Measures Active
- [ ] Firewall configured (only essential ports open)
- [ ] SSH restricted to Tailscale only  
- [ ] Fail2ban active and monitoring
- [ ] Automatic security updates enabled
- [ ] All passwords changed from defaults

---

## 📞 Emergency Procedures

### If Migration Fails
```bash
# Keep Contabo running as backup
# Start fresh on OVH and re-sync from scratch
# Takes 3-5 days but guarantees working setup
```

### If Bitcoin Won't Start
```bash
# Check logs
docker logs bitcoind

# Common issues:
# 1. Corrupted data - restore from backup
# 2. Permissions - fix with chown
# 3. Disk space - check with df -h
```

### If Family Can't Access Services
```bash
# Check Tailscale status
tailscale status

# Verify firewall
sudo ufw status

# Check service status
docker ps
```

---

## 🎯 Success Metrics

**Migration is successful when**:
- ✅ Bitcoin sync resumes from Contabo block height
- ✅ All family members can access via Tailscale
- ✅ BTCPay Server works via public domain
- ✅ Mobile wallets connect to family Electrum server
- ✅ Lightning Network operational
- ✅ Monthly cost reduced by $20 ($240/year saved!)

**Total migration time**: 8-12 hours over 1-2 days
**Cost savings achieved**: $240/year (37% reduction)
**Storage increase**: 1.5TB → 4TB+ (2.5x more space)

---

🏠 **Your Medampudi family Bitcoin infrastructure will be running on OVH with better performance, lower cost, and the same security standards!** 🚀