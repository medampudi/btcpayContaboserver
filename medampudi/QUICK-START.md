# 🚀 Quick Start Guide - Medampudi Family
## Execute This ASAP on Your OVH Ubuntu 24.04 Server

### 📋 Before You Start
1. **SSH into your OVH server as ubuntu user**: `ssh ubuntu@YOUR_OVH_IP`
2. **OVH Ubuntu servers come pre-configured with ubuntu user - no need to create admin user**
   ```bash
   # Verify you're logged in as ubuntu with sudo access
   whoami  # Should show: ubuntu
   sudo -l # Should show sudo permissions
   ```

### ⚡ One-Command Setup
```bash
# Download and run the automated setup script
wget -O setup.sh https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-automated-setup.sh
chmod +x setup.sh

# IMPORTANT: Edit configuration first!
nano setup.sh
# Change these lines:
# - DOMAIN_NAME="your-bitcoin-domain.com" 
# - BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"
# - EMAIL="your-email@domain.com"
# - All passwords (make them strong!)
# - Get TAILSCALE_AUTHKEY from https://login.tailscale.com/admin/settings/keys

# Run the setup (takes 2-3 hours)
./setup.sh
```

### 🔄 After Setup - Migrate Bitcoin Data
```bash
# Run the migration script
cd /opt/bitcoin
./scripts/migrate-from-contabo.sh

# This will:
# 1. Connect to your Contabo server
# 2. Backup blockchain data (saves 3-5 days sync!)
# 3. Transfer to OVH server  
# 4. Restore and start Bitcoin
```

### ☁️ Setup Tailscale & Cloudflare
```bash
# Download and run network setup
wget -O network-setup.sh https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/tailscale-cloudflare-setup.sh
chmod +x network-setup.sh

# Edit configuration first!
nano network-setup.sh
# Change:
# - DOMAIN_NAME
# - TAILSCALE_AUTHKEY  
# - CLOUDFLARE_API_TOKEN

# Run network setup
./network-setup.sh
```

### ✅ Verification Commands
```bash
# Check all services status
cd /opt/bitcoin && ./scripts/bitcoin-status.sh

# Get family access URLs
./scripts/family-access.sh

# Test network connectivity
./scripts/network-diagnostics.sh
```

### 📱 Family Member Setup
Send this to family:
1. **Install Tailscale** on phone/computer
2. **Sign in** with family account
3. **Access Bitcoin services** via Tailscale IP
4. **BTCPay Server**: https://pay.your-domain.com

### 🎯 Success Indicators
- ✅ Bitcoin Core synced (should resume from Contabo block)
- ✅ All Docker containers running
- ✅ Tailscale connected with family IP
- ✅ BTCPay accessible via domain
- ✅ Family can access via mobile wallets

### 💰 Cost Savings Achieved
- **Old**: $54/month Contabo
- **New**: $34/month OVH  
- **Savings**: $20/month ($240/year!)

### 📞 If Something Goes Wrong
```bash
# Check Docker services
docker ps

# Check logs
docker logs bitcoind
docker logs fulcrum

# Restart everything
cd /opt/bitcoin && docker compose down && docker compose up -d

# Network issues
sudo systemctl status tailscaled
sudo systemctl status cloudflared
```

---
**🏠 Total setup time: 4-8 hours**
**🎯 Result: Complete family Bitcoin sovereignty with $240/year savings!**