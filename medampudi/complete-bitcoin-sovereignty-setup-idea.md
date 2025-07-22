# 🚀 Bitcoin Sovereignty Migration: Contabo → OVH
## Complete Setup Guide for Rajesh's Family Bitcoin Infrastructure

### 💰 Cost Savings Achieved
**Moving from Contabo ($54/month) to OVH SYS-LE-1 ($34/month)**
- **Monthly Savings**: $20 (37% reduction)
- **Annual Savings**: $240
- **Storage Increase**: 1.5TB → 4TB (2.5x more space)

### 🎯 OVH Server Details
**Recommended: SYS-LE-1**
- **CPU**: Intel Atom C2750 (8 cores/8 threads @ 2.4GHz)
- **RAM**: 16GB (sufficient for family Bitcoin infrastructure)
- **Storage**: 2×4TB HDD RAID-1 (4TB usable)
- **Price**: ₹2,852/month (~$34/month)
- **Location**: Mumbai/Pune (better latency from India)

### Prerequisites
- OVH SYS-LE-1 server or similar (minimum: 8 CPU, 16GB RAM, 4TB storage)
- Domain name with Cloudflare DNS management
- Basic Linux knowledge
- Existing Contabo server data for migration

### 👨‍👩‍👧‍👦 Family Configuration Variables
Set these for your family setup:
```bash
# CHANGE THESE VALUES FOR YOUR FAMILY
DOMAIN_NAME="your-bitcoin-domain.com"
BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"
NODE_SUBDOMAIN="node"
EMAIL="rajesh@your-email.com"
FAMILY_NAME="Rajesh-Family"

# Family Members for Access Management
FAMILY_MEMBERS="Rajesh Apoorva Meera Vidur Ravi Bhavani Ramya Sumanth Viren Naina"

# Passwords - CHANGE ALL OF THESE - Make them strong!
BITCOIN_RPC_USER="family_rpc_user"
BITCOIN_RPC_PASS="YourSecureRPCPassword2025!"
POSTGRES_PASS="FamilyPostgresPass2025!"
MARIADB_ROOT_PASS="FamilyMariaDBRoot2025!"
MARIADB_MEMPOOL_PASS="FamilyMempoolPass2025!"

# India-specific settings
TIMEZONE="Asia/Kolkata"
CURRENCY_DISPLAY="INR"
```

## Phase 1: Initial Server Setup

### Step 1.1: First Login and System Update
```bash
# Login to your server (use password from Contabo)
ssh root@YOUR_SERVER_IP

# Create admin user
adduser admin
usermod -aG sudo admin

# Add your SSH key
su - admin
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "YOUR_SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Update system
sudo apt update && sudo apt upgrade -y
```

### Step 1.2: Install Essential Packages
```bash
# Install required packages
sudo apt install -y \
    curl wget git vim htop ncdu \
    ufw fail2ban net-tools \
    software-properties-common \
    jq

# Set timezone to India
sudo timedatectl set-timezone ${TIMEZONE}

# Configure swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Step 1.3: Secure SSH
```bash
# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Add/modify these lines:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers admin
```

## Phase 1.5: Data Migration from Contabo (Optional)

⚠️ **Important**: If you're migrating from existing Contabo server, do this BEFORE setting up services on OVH.

### Step 1.5.1: Backup Essential Data from Contabo
```bash
# SSH into your Contabo server
ssh admin@YOUR_CONTABO_IP

# Create backup directory
mkdir -p /tmp/migration-backup

# Backup Bitcoin blockchain data (CRITICAL - saves days of sync)
sudo tar -czf /tmp/migration-backup/bitcoin_chainstate.tar.gz \
    /opt/bitcoin/data/bitcoin/chainstate \
    /opt/bitcoin/data/bitcoin/blocks

# Backup Lightning channel data
sudo tar -czf /tmp/migration-backup/lightning_data.tar.gz \
    /opt/bitcoin/btcpay/btcpayserver-docker/btcpay_datadir/lightning

# Backup BTCPay configuration
sudo tar -czf /tmp/migration-backup/btcpay_config.tar.gz \
    /opt/bitcoin/btcpay/btcpayserver-docker/.env \
    /opt/bitcoin/btcpay/btcpayserver-docker/btcpay_datadir

# Backup custom configurations
cp /opt/bitcoin/configs/* /tmp/migration-backup/
cp /opt/bitcoin/docker-compose.yml /tmp/migration-backup/

# Transfer to OVH server (run this on Contabo)
rsync -avz --progress /tmp/migration-backup/ admin@YOUR_OVH_IP:/tmp/restore-data/
```

### Step 1.5.2: Restore Data on OVH Server
```bash
# On OVH server - restore blockchain data (saves 3-5 days sync time)
sudo mkdir -p /opt/bitcoin/data/bitcoin
cd /tmp/restore-data
sudo tar -xzf bitcoin_chainstate.tar.gz -C /opt/bitcoin/data/bitcoin/

# Restore Lightning data
sudo mkdir -p /opt/bitcoin/btcpay/btcpayserver-docker/btcpay_datadir
sudo tar -xzf lightning_data.tar.gz -C /opt/bitcoin/btcpay/btcpayserver-docker/

# Restore BTCPay config
sudo tar -xzf btcpay_config.tar.gz -C /opt/bitcoin/btcpay/btcpayserver-docker/

# Set proper ownership
sudo chown -R $USER:$USER /opt/bitcoin

echo "✅ Data migration complete - Bitcoin sync should resume from current block!"
```

## Phase 2: Tailscale Setup (Secure SSH Access)

### Step 2.1: Install Tailscale
```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up

# Note your Tailscale IP (100.x.x.x)
ip addr show tailscale0
```

### Step 2.2: Lock Down SSH to Tailscale
```bash
# Get your Tailscale IP
TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Update SSH to listen only on Tailscale
sudo sed -i "s/#ListenAddress 0.0.0.0/ListenAddress $TAILSCALE_IP\nListenAddress 127.0.0.1/" /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart ssh
```

## Phase 3: Firewall Configuration

```bash
# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow only essential public services
sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp   # HTTPS (for BTCPay)
sudo ufw allow 8333/tcp  # Bitcoin P2P
sudo ufw allow 9735/tcp  # Lightning Network

# Do NOT open these ports (Tailscale only):
# 8332 (Bitcoin RPC)
# 50001/50002 (Electrum)
# 8080 (Mempool)
# 3002 (Explorer)

# Allow Tailscale
sudo ufw allow in on tailscale0

# Enable firewall
sudo ufw --force enable
```

## Phase 4: Docker Installation

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install docker-compose
sudo apt install -y docker-compose-v2

# Apply group changes
newgrp docker

# Verify installation
docker --version
docker compose version
```

## Phase 5: Cloudflare Tunnel Setup

### Step 5.1: Install Cloudflared
```bash
# Add Cloudflare repository
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Install cloudflared
sudo apt update
sudo apt install cloudflared
```

### Step 5.2: Create Tunnel
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create bitcoin-server

# Note the tunnel ID
cloudflared tunnel list
```

### Step 5.3: Configure Tunnel (Secure Setup - BTCPay Only)
```bash
# Create config directory
sudo mkdir -p /etc/cloudflared

# Create config file
sudo nano /etc/cloudflared/config.yml
```

Add this configuration (replace TUNNEL_ID and domain names):
```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/admin/.cloudflared/YOUR_TUNNEL_ID.json

originRequest:
  noTLSVerify: true

ingress:
  # ONLY BTCPay is publicly exposed
  - hostname: pay.yourdomain.com
    service: http://localhost:80
    
  # All other services accessed via Tailscale only
  - service: http_status:404
```

**Security Note**: All internal services (Mempool, Explorer, Electrum, etc.) will be accessed via Tailscale IP only. This significantly reduces attack surface.

### Step 5.4: Install Tunnel as Service
```bash
# Copy credentials
sudo cp ~/.cloudflared/*.json /etc/cloudflared/

# Install service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

### Step 5.5: Configure DNS
In Cloudflare Dashboard, add CNAME record:
```
pay → YOUR_TUNNEL_ID.cfargotunnel.com (Proxied)
```

**Note**: Only add DNS for pay.yourdomain.com. All other services will be accessed via Tailscale.

## Phase 6: Bitcoin Stack Setup

### Step 6.1: Create Directory Structure
```bash
# Create directories
sudo mkdir -p /opt/bitcoin/{data,configs,mysql,backups}
sudo chown -R $USER:$USER /opt/bitcoin
cd /opt/bitcoin
```

### Step 6.2: Create Configuration Files

**Create Fulcrum config:**
```bash
mkdir -p configs
cat > configs/fulcrum.conf << EOF
datadir = /data
bitcoind = bitcoind:8332
rpcuser = ${BITCOIN_RPC_USER}
rpcpassword = ${BITCOIN_RPC_PASS}

tcp = 0.0.0.0:50001
ssl = 0.0.0.0:50002

cert = /data/fulcrum.crt
key = /data/fulcrum.key
peering = false

fast-sync = 1
db_max_open_files = 500
db_mem = 8000.0
bitcoind_timeout = 300
bitcoind_clients = 4
EOF
```

**Create Mempool config:**
```bash
cat > configs/mempool-config.json << EOF
{
  "MEMPOOL": {
    "NETWORK": "mainnet",
    "BACKEND": "electrum",
    "HTTP_PORT": 8999,
    "API_URL_PREFIX": "/api/v1/",
    "POLL_RATE_MS": 2000
  },
  "CORE_RPC": {
    "HOST": "bitcoind",
    "PORT": 8332,
    "USERNAME": "${BITCOIN_RPC_USER}",
    "PASSWORD": "${BITCOIN_RPC_PASS}"
  },
  "ELECTRUM": {
    "HOST": "fulcrum",
    "PORT": 50001,
    "TLS_ENABLED": false
  },
  "DATABASE": {
    "ENABLED": true,
    "HOST": "mempool-db",
    "PORT": 3306,
    "DATABASE": "mempool",
    "USERNAME": "mempool",
    "PASSWORD": "${MARIADB_MEMPOOL_PASS}"
  }
}
EOF
```

### Step 6.3: Create Docker Compose File
```bash
cat > docker-compose.yml << EOF
networks:
  bitcoin:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

volumes:
  bitcoin_data:
  fulcrum_data:
  postgres_data:
  lightning_data:
  mempool_data:

services:
  # Bitcoin Core - Full Node
  bitcoind:
    image: btcpayserver/bitcoin:26.0
    container_name: bitcoind
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.10
    volumes:
      - bitcoin_data:/data
    environment:
      BITCOIN_NETWORK: mainnet
      BITCOIN_EXTRA_ARGS: |
        rpcuser=${BITCOIN_RPC_USER}
        rpcpassword=${BITCOIN_RPC_PASS}
        rpcallowip=172.25.0.0/16
        rpcallowip=127.0.0.1
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
        listenonion=0
        zmqpubrawblock=tcp://0.0.0.0:28332
        zmqpubrawtx=tcp://0.0.0.0:28333
        whitelist=172.25.0.0/16
        maxconnections=125
        dbcache=4000
        maxmempool=2000
        mempoolexpiry=72
    ports:
      - "8333:8333"  # P2P - Keep public for network health
      # Bitcoin RPC only via Tailscale

  # Fulcrum - Electrum Server
  fulcrum:
    image: cculianu/fulcrum:latest
    container_name: fulcrum
    restart: unless-stopped
    depends_on:
      - bitcoind
    networks:
      bitcoin:
        ipv4_address: 172.25.0.20
    volumes:
      - fulcrum_data:/data
      - ./configs/fulcrum.conf:/etc/fulcrum.conf
    # No external ports - access via Tailscale only
    environment:
      - DATA_DIR=/data

  # PostgreSQL for BTCPay
  postgres:
    image: postgres:15
    container_name: postgres
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.30
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: btcpay
      POSTGRES_USER: btcpay
      POSTGRES_PASSWORD: ${POSTGRES_PASS}

  # Mempool Database
  mempool-db:
    image: mariadb:10.5
    container_name: mempool-db
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.40
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      MYSQL_DATABASE: mempool
      MYSQL_USER: mempool
      MYSQL_PASSWORD: ${MARIADB_MEMPOOL_PASS}
      MYSQL_ROOT_PASSWORD: ${MARIADB_ROOT_PASS}

  # Mempool API
  mempool-api:
    image: mempool/backend:latest
    container_name: mempool-api
    restart: unless-stopped
    depends_on:
      - bitcoind
      - fulcrum
      - mempool-db
    networks:
      bitcoin:
        ipv4_address: 172.25.0.41
    volumes:
      - ./configs/mempool-config.json:/backend/mempool-config.json
    environment:
      MEMPOOL_BACKEND: "electrum"
      ELECTRUM_HOST: "fulcrum"
      ELECTRUM_PORT: "50001"
      ELECTRUM_TLS_ENABLED: "false"
      CORE_RPC_HOST: "bitcoind"
      CORE_RPC_PORT: "8332"
      CORE_RPC_USERNAME: "${BITCOIN_RPC_USER}"
      CORE_RPC_PASSWORD: "${BITCOIN_RPC_PASS}"
      DATABASE_ENABLED: "true"
      DATABASE_HOST: "mempool-db"
      DATABASE_DATABASE: "mempool"
      DATABASE_USERNAME: "mempool"
      DATABASE_PASSWORD: "${MARIADB_MEMPOOL_PASS}"

  # Mempool Frontend
  mempool-web:
    image: mempool/frontend:latest
    container_name: mempool-web
    restart: unless-stopped
    depends_on:
      - mempool-api
    networks:
      bitcoin:
        ipv4_address: 172.25.0.42
    # No external ports - access via Tailscale only
    environment:
      FRONTEND_HTTP_PORT: "8080"
      BACKEND_MAINNET_HTTP_HOST: "mempool-api"

  # BTC RPC Explorer
  btc-rpc-explorer:
    image: btcpayserver/btc-rpc-explorer:latest
    container_name: btc-explorer
    restart: unless-stopped
    depends_on:
      - bitcoind
      - fulcrum
    networks:
      bitcoin:
        ipv4_address: 172.25.0.50
    # No external ports - access via Tailscale only
    environment:
      BTCEXP_HOST: 0.0.0.0
      BTCEXP_PORT: 3002
      BTCEXP_BITCOIND_HOST: bitcoind
      BTCEXP_BITCOIND_PORT: 8332
      BTCEXP_BITCOIND_USER: ${BITCOIN_RPC_USER}
      BTCEXP_BITCOIND_PASS: ${BITCOIN_RPC_PASS}
      BTCEXP_ELECTRUM_SERVERS: tcp://fulcrum:50001
      BTCEXP_SLOW_DEVICE_MODE: false
      BTCEXP_NO_INMEMORY_RPC_CACHE: false
EOF
```

### Step 6.4: Start Bitcoin Stack
```bash
# Start Bitcoin Core first
docker compose up -d bitcoind

# Check logs
docker logs -f bitcoind

# Create monitoring script
cat > check-bitcoin.sh << 'EOF'
#!/bin/bash
docker exec bitcoind bitcoin-cli \
  -rpcuser=${BITCOIN_RPC_USER} \
  -rpcpassword=${BITCOIN_RPC_PASS} \
  getblockchaininfo | jq '{chain, blocks, headers, verificationprogress, size_on_disk}'
EOF

chmod +x check-bitcoin.sh
```

## Phase 7: BTCPay Server Setup

### Step 7.1: Prepare BTCPay Directory
```bash
cd /opt/bitcoin
mkdir -p btcpay
cd btcpay

# Clone BTCPay Docker
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker
```

### Step 7.2: Configure BTCPay
```bash
# Create environment file
cat > btcpay.env << EOF
export BTCPAY_HOST="${BTCPAY_DOMAIN}"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="bitcoin-nobitcoind;opt-add-thunderhub"
export BTCPAY_ENABLE_SSH=true
export BTCPAY_EXTERNAL_BITCOIND_HOST="172.25.0.10"
export BTCPAY_EXTERNAL_BITCOIND_RPCPORT="8332"
export BTCPAY_EXTERNAL_BITCOIND_RPCUSER="${BITCOIN_RPC_USER}"
export BTCPAY_EXTERNAL_BITCOIND_RPCPASSWORD="${BITCOIN_RPC_PASS}"
EOF

# Source and install
source btcpay.env
./btcpay-setup.sh -i
```

## Phase 8: Complete Service Deployment

### Step 8.1: Start Remaining Services
```bash
cd /opt/bitcoin

# After Bitcoin is 50% synced, start databases
docker compose up -d postgres mempool-db

# After Bitcoin is 90% synced, start Fulcrum
docker compose up -d fulcrum

# Start remaining services
docker compose up -d mempool-api mempool-web btc-rpc-explorer
```

### Step 8.2: Create Tailscale Service Access Script
```bash
cat > /opt/bitcoin/tailscale-services.sh << 'EOF'
#!/bin/bash
TAILSCALE_IP=$(tailscale ip -4)

echo "=== Access your services via Tailscale ==="
echo "========================================"
echo ""
echo "Internal Services (Tailscale Only):"
echo "Mempool Explorer:    http://$TAILSCALE_IP:8080"
echo "BTC RPC Explorer:    http://$TAILSCALE_IP:3002"
echo "Electrum Server:     $TAILSCALE_IP:50001 (TCP)"
echo "Electrum Server SSL: $TAILSCALE_IP:50002 (SSL)"
echo "Bitcoin RPC:         $TAILSCALE_IP:8332"
echo "Lightning (Thunderhub): http://$TAILSCALE_IP:3000"
echo ""
echo "Public Services:"
echo "BTCPay:              https://${BTCPAY_DOMAIN}"
echo ""
echo "SSH Access:          ssh admin@$TAILSCALE_IP"
echo ""
echo "Electrum Wallet Configuration:"
echo "Server: $TAILSCALE_IP"
echo "Port: 50001 (TCP) or 50002 (SSL)"
EOF

chmod +x /opt/bitcoin/tailscale-services.sh
./tailscale-services.sh
```

### Step 8.3: Create Status Dashboard
```bash
cat > /opt/bitcoin/status.sh << 'EOF'
#!/bin/bash
clear
echo "=== Bitcoin Sovereignty Stack Status ==="
echo "========================================"
echo ""
echo "=== Bitcoin Core ==="
./check-bitcoin.sh
echo ""
echo "=== Docker Services ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}"
echo ""
echo "=== System Resources ==="
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
echo "Disk Usage:"
df -h | grep -E "Filesystem|/opt/bitcoin|/$"
echo ""
echo "=== Access Information ==="
echo "Run './tailscale-services.sh' to see service URLs"
echo ""
echo "=== Security Status ==="
echo "Firewall: $(sudo ufw status | grep Status | awk '{print $2}')"
echo "Tailscale: $(tailscale status | grep -q "Logged out" && echo "Not Connected" || echo "Connected")"
EOF

chmod +x /opt/bitcoin/status.sh
```

## Phase 9: Security Hardening

### Step 9.1: Configure Fail2ban
```bash
# Create jail configuration
sudo nano /etc/fail2ban/jail.local

# Add:
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

# Restart fail2ban
sudo systemctl restart fail2ban
```

### Step 9.2: Enable Automatic Updates
```bash
# Configure unattended upgrades
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure to auto-reboot if needed
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Uncomment and set:
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

## Phase 10: Backup Configuration

### Step 10.1: Create Backup Script
```bash
cat > /opt/bitcoin/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/bitcoin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
REMOTE_BACKUP="user@backup-server:/path/to/backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configurations
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz \
    /opt/bitcoin/configs \
    /opt/bitcoin/docker-compose.yml \
    /opt/bitcoin/btcpay/btcpayserver-docker/.env

# Backup BTCPay
if [ -d "/opt/bitcoin/btcpay/btcpayserver-docker" ]; then
    cd /opt/bitcoin/btcpay/btcpayserver-docker
    ./btcpay-backup.sh $BACKUP_DIR/btcpay_$DATE.tar.gz
fi

# Backup Lightning channel state
docker exec btcpayserver_clightning lightning-cli listchannels > $BACKUP_DIR/channels_$DATE.json

# Optional: Sync to remote server
# rsync -avz $BACKUP_DIR/ $REMOTE_BACKUP/

# Keep only last 7 days locally
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.json" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/bitcoin/backup.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/bitcoin/backup.sh") | crontab -
```

## Phase 11: Monitoring and Alerts

### Step 11.1: Create Health Check Script
```bash
cat > /opt/bitcoin/health-check.sh << 'EOF'
#!/bin/bash

# Check if services are running
SERVICES=("bitcoind" "fulcrum" "mempool-api" "btcpayserver")
ALERT_EMAIL="${EMAIL}"

for service in "${SERVICES[@]}"; do
    if ! docker ps | grep -q $service; then
        echo "Service $service is not running!" | mail -s "Bitcoin Node Alert" $ALERT_EMAIL
    fi
done

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo "Disk usage is at ${DISK_USAGE}%!" | mail -s "Bitcoin Node Disk Alert" $ALERT_EMAIL
fi
EOF

chmod +x /opt/bitcoin/health-check.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/15 * * * * /opt/bitcoin/health-check.sh") | crontab -
```

## Usage Instructions

### Connecting Electrum Wallet
```
# Use your Tailscale IP
Server: [Your-Tailscale-IP]
Port: 50001 (TCP) or 50002 (SSL)

# Example:
Server: 100.95.182.29
Port: 50001
```

### Accessing Services

**Public Access (Anyone):**
- BTCPay: https://pay.yourdomain.com

**Private Access (Tailscale Only):**
- Mempool: http://[tailscale-ip]:8080
- Explorer: http://[tailscale-ip]:3002
- Lightning: http://[tailscale-ip]:3000
- Bitcoin RPC: [tailscale-ip]:8332

### SSH Access
```bash
# Via Tailscale (primary method)
ssh admin@[tailscale-ip]

# Example
ssh admin@100.95.182.29

# Emergency access (if Tailscale fails)
# Use Contabo VNC console
```

### Security Note
All internal services are ONLY accessible via Tailscale. This provides:
- Zero public attack surface
- Strong authentication
- Complete audit trail
- No complex firewall rules needed

## Maintenance Commands

### Check Status
```bash
cd /opt/bitcoin
./status.sh
```

### Update Services
```bash
cd /opt/bitcoin
docker compose pull
docker compose up -d
```

### View Logs
```bash
# Bitcoin
docker logs -f bitcoind

# BTCPay
docker logs -f btcpayserver

# Any service
docker logs -f [container-name]
```

### Backup Now
```bash
/opt/bitcoin/backup.sh
```

## Troubleshooting

### Service Won't Start
```bash
# Check logs
docker logs [service-name]

# Restart service
docker compose restart [service-name]

# Check disk space
df -h
```

### Bitcoin Sync Issues
```bash
# Check peers
docker exec bitcoind bitcoin-cli getpeerinfo | jq length

# Add nodes manually
docker exec bitcoind bitcoin-cli addnode "node.address" add
```

### BTCPay Issues
```bash
cd /opt/bitcoin/btcpay/btcpayserver-docker
./btcpay-down.sh
./btcpay-up.sh
```

## Security Best Practices

1. **Regular Updates**
   - System: `sudo apt update && sudo apt upgrade`
   - Docker: `docker compose pull && docker compose up -d`

2. **Monitor Logs**
   - Auth logs: `sudo tail -f /var/log/auth.log`
   - Nginx logs: `sudo tail -f /var/log/nginx/access.log`

3. **Backup Verification**
   - Test restore monthly
   - Keep offsite copies

4. **Access Control**
   - Use Tailscale for SSH
   - Enable 2FA on Cloudflare
   - Rotate passwords quarterly

## Estimated Timeline

- Initial setup: 2-4 hours
- Bitcoin sync: 2-5 days
- Fulcrum sync: 12-24 hours after Bitcoin
- Total to operational: 3-6 days

## Cost Considerations

- Server: €49/month (Contabo Storage VPS 50)
- Domain: ~€10/year
- Total: ~€50/month

## Support Resources

- BTCPay: https://docs.btcpayserver.org/
- Bitcoin Core: https://bitcoin.org/en/full-node
- Fulcrum: https://github.com/cculianu/Fulcrum
- Mempool: https://github.com/mempool/mempool
- Community: https://t.me/btcpayserver

---

**Remember**: This creates a fully sovereign Bitcoin infrastructure. You control your node, your verification, and your payment processing. No third parties required!