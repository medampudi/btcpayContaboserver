# 🚀 Automated Bitcoin Sovereignty Setup

Complete automated setup for a family Bitcoin infrastructure including full node, payment processing, Lightning Network, and private blockchain explorers.

## 📋 What This Setup Includes

- **Bitcoin Core** - Full validating node
- **Fulcrum** - High-performance Electrum server for wallets
- **BTCPay Server** - Self-hosted payment processor with Lightning
- **Lightning Network** - Instant Bitcoin payments
- **Mempool Explorer** - Beautiful blockchain explorer
- **BTC RPC Explorer** - Alternative blockchain explorer
- **Tailscale VPN** - Secure remote access for family
- **Cloudflare Tunnel** - Safe public access for BTCPay only
- **Automated Backups** - Daily backups of critical data
- **Health Monitoring** - Automatic alerts for issues

## 💰 Cost Savings

- **Current Contabo**: $54/month
- **Recommended OVH**: $34/month  
- **Monthly Savings**: $20 (37%)
- **Annual Savings**: $240

## 🖥️ Server Requirements

### Ubuntu Version
- **Recommended**: Ubuntu 22.04 LTS (best compatibility)
- **Alternative**: Ubuntu 24.04 LTS (newer but less tested)

### Minimum Hardware
- **CPU**: 4 cores (8 cores recommended)
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: 2TB minimum (4TB recommended)
- **Bandwidth**: Unlimited preferred

### Recommended Servers

#### For Families (Best Value)
**OVH SYS-LE-1** - $34/month
- Intel Atom C2750 (8 cores @ 2.4GHz)
- 16GB RAM (sufficient for family use)
- 4TB storage (2×4TB RAID-1)
- Unlimited bandwidth
- Mumbai location (low latency from India)

#### For Growing Needs
**OVH SYS-LE-2** - $42/month
- Better CPU performance
- 32GB RAM
- 4TB storage

## 🔧 Setup Instructions

### Step 1: Order Your Server

1. Go to [OVH.com](https://www.ovh.com)
2. Choose Dedicated Servers → Eco Series
3. Select SYS-LE-1 (or your preferred option)
4. Choose Ubuntu 22.04 LTS as the OS
5. Complete the order

### Step 2: Initial Server Access

Once you receive your server credentials:

```bash
# SSH into your server
ssh ubuntu@YOUR_SERVER_IP

# Become root user
sudo su -

# Download the setup files
cd /root
git clone https://github.com/yourusername/btcpayserver-setup.git
cd btcpayserver-setup/medampudi

# Or download directly:
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/setup-config.env
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/setup-bitcoin-node.sh
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/bitcoin-sovereignty-setup.sh

# Make scripts executable
chmod +x *.sh
```

### Step 3: Configure Your Setup

Edit the configuration file:

```bash
nano setup-config.env
```

**Essential changes:**

1. **Domain Settings**:
   ```bash
   DOMAIN_NAME="your-actual-domain.com"        # Your domain
   BTCPAY_DOMAIN="pay.your-actual-domain.com"  # BTCPay subdomain
   EMAIL="your-email@gmail.com"                # Your email
   FAMILY_NAME="YourFamily"                     # Your family name
   ```

2. **Passwords** (MUST CHANGE ALL):
   ```bash
   BITCOIN_RPC_PASS="YourVeryStrongPassword123!@#"
   POSTGRES_PASS="AnotherStrongPassword456!@#"
   MARIADB_ROOT_PASS="RootStrongPassword789!@#"
   MARIADB_MEMPOOL_PASS="MempoolStrongPass321!@#"
   ```

3. **Tailscale Auth Key** (REQUIRED):
   - Go to https://login.tailscale.com/admin/settings/keys
   - Click "Generate auth key"
   - Enable "Reusable"
   - Copy and paste into config:
   ```bash
   TAILSCALE_AUTHKEY="tskey-auth-xxxxx-xxxxxxxxx"
   ```

4. **Optional - Cloudflare API** (for automated tunnel):
   - Get API token from Cloudflare dashboard
   - Or leave empty for manual setup

### Step 4: Run the Setup

```bash
# Run the setup wrapper
./setup-bitcoin-node.sh
```

The script will:
- Validate your configuration
- Show a summary
- Ask for confirmation
- Run the complete setup (30-45 minutes)

### Step 5: Post-Setup Tasks

#### If Tailscale didn't auto-connect:
```bash
sudo tailscale up
# Follow the URL to authenticate
```

#### If Cloudflare tunnel needs manual setup:
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create family-bitcoin

# Get the tunnel ID from output, then:
cloudflared tunnel route dns family-bitcoin pay.yourdomain.com

# Start tunnel
cd /opt/bitcoin
sudo systemctl start cloudflared
```

### Step 6: Monitor Progress

```bash
# Check Bitcoin sync status
cd /opt/bitcoin
./scripts/status.sh

# Watch Bitcoin logs
docker logs -f bitcoind

# Get access URLs
./scripts/access-info.sh
```

## 📱 Family Access Setup

### For Family Members:

1. **Install Tailscale** on their device:
   - iOS/Android: Download from App Store/Play Store
   - Desktop: https://tailscale.com/download

2. **Share your Tailscale network**:
   - Go to https://login.tailscale.com/admin/users
   - Click "Invite users"
   - Send invite to family member's email

3. **Configure their Bitcoin wallet**:
   - Install Blue Wallet (mobile) or Electrum (desktop)
   - Add your Electrum server:
     - Server: `[Your-Tailscale-IP]`
     - Port: `50001`
     - SSL: Disabled

### Service URLs (via Tailscale):
- Mempool Explorer: `http://[tailscale-ip]:8080`
- Bitcoin Explorer: `http://[tailscale-ip]:3002`
- Lightning Manager: `http://[tailscale-ip]:3000`

### Public Access:
- BTCPay Server: `https://pay.yourdomain.com`

## 🔒 Security Features

- **No Public SSH**: SSH locked to Tailscale VPN only
- **Minimal Attack Surface**: Only BTCPay exposed publicly
- **Automatic Security Updates**: Unattended upgrades enabled
- **Intrusion Prevention**: Fail2ban configured
- **Firewall**: UFW with strict rules
- **Encrypted Backups**: Daily automated backups

## 🛠️ Maintenance

### Daily Tasks (Automated)
- Health checks every 15 minutes
- Backup at 3 AM daily
- Log rotation

### Weekly Tasks
- Check system status: `./scripts/status.sh`
- Review logs: `docker logs [service-name]`

### Monthly Tasks
- Test backup restoration
- Update system: `apt update && apt upgrade`
- Check disk space: `df -h`

## 🚨 Troubleshooting

### Bitcoin won't sync
```bash
# Check peers
docker exec bitcoind bitcoin-cli getpeerinfo | jq length

# Add nodes if needed
docker exec bitcoind bitcoin-cli addnode "node.bitcoin.org" add
```

### Service not starting
```bash
# Check logs
docker logs [service-name]

# Restart service
docker compose restart [service-name]

# Restart all
cd /opt/bitcoin
docker compose down
docker compose up -d
```

### Can't access via Tailscale
```bash
# Check Tailscale status
tailscale status

# Restart Tailscale
sudo systemctl restart tailscale
```

### Disk space issues
```bash
# Check usage
df -h
du -sh /opt/bitcoin/*

# Clean Docker
docker system prune -a
```

## 📊 Expected Timeline

1. **Initial Setup**: 30-45 minutes
2. **Bitcoin Initial Sync**: 2-5 days (depending on internet speed)
3. **Fulcrum Sync**: 12-24 hours (after Bitcoin syncs)
4. **Lightning Setup**: 10 minutes (after BTCPay starts)
5. **Total to Fully Operational**: 3-6 days

## 🎯 Success Indicators

You'll know your setup is complete when:
- ✅ `./scripts/status.sh` shows 100% Bitcoin sync
- ✅ All Docker containers show "Up" status
- ✅ You can access Mempool explorer via Tailscale
- ✅ BTCPay Server loads at https://pay.yourdomain.com
- ✅ Family members can connect wallets to your Electrum server

## 📞 Getting Help

1. **Check logs first**: `docker logs [service-name]`
2. **Run status check**: `./scripts/status.sh`
3. **BTCPay Community**: https://chat.btcpayserver.org/
4. **Bitcoin Stack Exchange**: https://bitcoin.stackexchange.com/

## 🎉 Congratulations!

Once setup is complete, you'll have:
- 🏦 Your own Bitcoin bank
- ⚡ Lightning Network node
- 💳 Payment processing system
- 🔍 Private blockchain explorers
- 👨‍👩‍👧‍👦 Secure family access
- 💰 $240/year in savings!

You're now part of the Bitcoin network, verifying your own transactions and achieving true financial sovereignty!