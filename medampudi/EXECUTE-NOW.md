# ⚡ EXECUTE NOW - Medampudi Family Bitcoin Migration
## Copy-Paste Commands for Immediate Execution

### 🎯 **Pre-Execution Checklist**
- ✅ OVH dedicated server with Ubuntu 24.04 running
- ✅ SSH access as `ubuntu` user: `ssh ubuntu@YOUR_OVH_IP`
- ✅ Domain registered and Cloudflare account ready
- ✅ Tailscale account created at https://login.tailscale.com

---

## 🔍 **STEP 1: Verify Server (2 minutes)**

```bash
# SSH into your OVH server
ssh ubuntu@YOUR_OVH_IP

# Download and run server verification
wget -O verify.sh https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-ubuntu-verification.sh
chmod +x verify.sh
./verify.sh
```

**Expected result**: Server readiness confirmation with ✅ green checkmarks

---

## 🚀 **STEP 2: Automated Server Setup (2-3 hours)**

### Download Setup Script
```bash
# Download the main setup script
wget -O setup.sh https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-automated-setup.sh
chmod +x setup.sh
```

### ⚠️ **CRITICAL: Edit Configuration**
```bash
# Open setup script for editing
nano setup.sh

# CHANGE THESE LINES (around line 20-35):
# DOMAIN_NAME="your-bitcoin-domain.com"           → YOUR ACTUAL DOMAIN
# BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"     → YOUR BTCPAY SUBDOMAIN
# EMAIL="your-email@domain.com"                   → YOUR EMAIL
# BITCOIN_RPC_PASS="YourSecureRPCPassword2025!"   → STRONG PASSWORD
# POSTGRES_PASS="FamilyPostgres2025!"             → STRONG PASSWORD
# MARIADB_ROOT_PASS="FamilyMariaRoot2025!"        → STRONG PASSWORD
# MARIADB_MEMPOOL_PASS="FamilyMempool2025!"      → STRONG PASSWORD

# GET TAILSCALE AUTH KEY:
# 1. Go to https://login.tailscale.com/admin/settings/keys
# 2. Generate new auth key
# 3. Copy and paste: TAILSCALE_AUTHKEY="tskey-auth-xxxxx"
```

### Execute Setup
```bash
# Run the automated setup
./setup.sh
```

**Expected duration**: 2-3 hours
**What it does**: Installs Docker, Tailscale, Cloudflare, Bitcoin infrastructure, security hardening

---

## 🔄 **STEP 3: Migrate Bitcoin Data from Contabo (4-8 hours)**

```bash
# Navigate to Bitcoin directory
cd /opt/bitcoin

# Run migration script
./scripts/migrate-from-contabo.sh
```

**When prompted**:
- Enter your Contabo server IP
- Enter Contabo username (usually: `admin`)
- Script will backup and transfer your synced blockchain

**Expected duration**: 4-8 hours depending on connection speed

---

## ☁️ **STEP 4: Setup Tailscale & Cloudflare (1 hour)**

### Download Network Setup Script
```bash
# Download network configuration script
wget -O network-setup.sh https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/tailscale-cloudflare-setup.sh
chmod +x network-setup.sh
```

### Configure Network Script
```bash
# Edit network setup configuration
nano network-setup.sh

# CHANGE THESE LINES:
# DOMAIN_NAME="your-domain.com"                   → YOUR ACTUAL DOMAIN
# TAILSCALE_AUTHKEY=""                           → YOUR TAILSCALE AUTH KEY
# CLOUDFLARE_EMAIL="your-email@domain.com"        → YOUR CLOUDFLARE EMAIL
# CLOUDFLARE_API_TOKEN=""                        → YOUR CLOUDFLARE API TOKEN

# GET CLOUDFLARE API TOKEN:
# 1. Go to https://dash.cloudflare.com/profile/api-tokens
# 2. Create Token → Custom Token
# 3. Permissions: Zone:Zone:Read, Zone:DNS:Edit
# 4. Zone Resources: Include Specific Zone → YOUR DOMAIN
```

### Execute Network Setup
```bash
# Run network configuration
./network-setup.sh
```

---

## ✅ **STEP 5: Verification & Testing (15 minutes)**

### Check All Services
```bash
cd /opt/bitcoin

# Check Bitcoin and services status
./scripts/bitcoin-status.sh

# Get family access information
./scripts/family-access.sh

# Test network connectivity
./scripts/network-diagnostics.sh
```

### Test Family Access
```bash
# Get your Tailscale IP
tailscale ip -4

# Test URLs (replace TAILSCALE_IP with actual IP):
# http://TAILSCALE_IP:8080 (Mempool Explorer)
# http://TAILSCALE_IP:3002 (Bitcoin Explorer)  
# https://pay.your-domain.com (BTCPay Server)
```

---

## 👨‍👩‍👧‍👦 **STEP 6: Family Setup (30 minutes)**

### Invite Family to Tailscale
1. Go to https://login.tailscale.com/admin/settings/users
2. Invite family members:
   - `apoorva@email.com`
   - `ravi@email.com`
   - `bhavani@email.com`
   - `ramya@email.com` (Kilaru)
   - `sumanth@email.com` (Kilaru)

### Share Access Information
```bash
# Generate family access info
./scripts/family-access.sh > family-access.txt

# Share family-access.txt with all family members
# They need to:
# 1. Install Tailscale app
# 2. Sign in with family account  
# 3. Use provided URLs/IPs
```

---

## 🎉 **SUCCESS INDICATORS**

### ✅ **Bitcoin Node**
- Blockchain fully synced (resumed from Contabo block height)
- All Docker containers running healthy
- Bitcoin RPC responding

### ✅ **Network Access**
- Tailscale connected with family IP
- BTCPay Server accessible via https://pay.your-domain.com
- Internal services accessible via Tailscale only

### ✅ **Family Access**
- All family members can install Tailscale
- Mobile wallets can connect to Electrum server
- Lightning payments working

### ✅ **Cost Savings**
- **Monthly savings**: $20 ($54 Contabo → $34 OVH)
- **Annual savings**: $240
- **Storage increase**: 2.5x more space (4TB vs 1.5TB)

---

## 🚨 **Emergency Commands**

### If Bitcoin Won't Start
```bash
# Check Bitcoin logs
docker logs bitcoind

# Restart Bitcoin
cd /opt/bitcoin
docker compose restart bitcoind
```

### If Services Are Down
```bash
# Check all containers
docker ps -a

# Restart everything
cd /opt/bitcoin
docker compose down
docker compose up -d
```

### If Network Issues
```bash
# Check Tailscale
tailscale status

# Restart Tailscale
sudo systemctl restart tailscaled

# Check Cloudflare tunnel
sudo systemctl status cloudflared
```

### If Need to Start Over
```bash
# Stop everything
cd /opt/bitcoin
docker compose down

# Remove containers (keeps data)
docker system prune -f

# Re-run setup
./setup.sh
```

---

## 📞 **Support & Troubleshooting**

### Quick Diagnostics
```bash
# Full system check
cd /opt/bitcoin && ./scripts/bitcoin-status.sh
./scripts/network-diagnostics.sh

# Check logs
docker logs bitcoind
docker logs fulcrum
sudo journalctl -u tailscaled
sudo journalctl -u cloudflared
```

### Family Support
- **Tailscale not connecting**: Check family member signed in with correct account
- **Can't access services**: Verify Tailscale IP and share fresh `family-access.txt`
- **BTCPay not loading**: Check Cloudflare tunnel status and DNS configuration

---

## 🎯 **Final Result**

**Your Medampudi family will have**:
- ✅ Complete Bitcoin sovereignty (your node, your rules)
- ✅ $240/year cost savings vs Contabo
- ✅ Secure family access via Tailscale VPN
- ✅ Public BTCPay Server for Bitcoin payments
- ✅ Lightning Network for instant family transfers
- ✅ Private Mempool/Explorer for blockchain analysis
- ✅ Mobile wallet connectivity for all family members
- ✅ Indian tax compliance automation ready

**Total execution time**: 8-12 hours over 1-2 days
**One-time effort for lifetime Bitcoin infrastructure!** 🚀

---

## 📋 **URL Quick Reference**

- **Server Verification**: https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-ubuntu-verification.sh
- **Main Setup**: https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/ovh-automated-setup.sh  
- **Network Setup**: https://raw.githubusercontent.com/medampudi/btcpayContaboserver/refs/heads/main/medampudi/tailscale-cloudflare-setup.sh
- **Tailscale Admin**: https://login.tailscale.com/admin/settings/keys
- **Cloudflare API**: https://dash.cloudflare.com/profile/api-tokens