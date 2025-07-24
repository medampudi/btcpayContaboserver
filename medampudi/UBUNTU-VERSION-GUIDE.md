# Ubuntu Version Selection Guide for Bitcoin Node

## Quick Answer: Ubuntu 22.04 LTS

**Recommended OS**: Ubuntu Server 22.04.3 LTS (Jammy Jellyfish)

## Why Ubuntu 22.04 LTS?

### ✅ Advantages
- **Long Term Support** until April 2027
- **Stable** - Battle-tested with Bitcoin software
- **Docker Compatibility** - Ships with Docker 20.10+
- **Security Updates** - 5 years of guaranteed updates
- **Wide Support** - Most Bitcoin guides use 22.04
- **BTCPay Tested** - Officially supported by BTCPay Server

### 📊 Comparison

| Feature | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS | Other Distros |
|---------|------------------|------------------|---------------|
| Support Until | April 2027 | April 2029 | Varies |
| Docker Version | 20.10+ | 24.0+ | Manual install |
| Bitcoin Software | ✅ Fully tested | ⚠️ Newer, less tested | ❌ Variable |
| BTCPay Support | ✅ Official | ⚠️ Works but newer | ❌ Not official |
| Stability | ✅ Very stable | ⚠️ Newer | Varies |

## Server Provider Specific Instructions

### OVH Servers
1. Log into OVH Manager
2. Go to your server's dashboard
3. Click "Install"
4. Choose "Ubuntu 22.04 Server"
5. Select "Use distribution kernel"
6. Set hostname and password
7. Install (takes ~10 minutes)

### Contabo VPS
1. Log into Customer Control Panel
2. Select your VPS
3. Click "Reinstall"
4. Choose "Ubuntu 22.04 LTS"
5. Note the root password
6. Confirm installation

### Hetzner
1. Access Robot Panel
2. Select server
3. Choose "Linux"
4. Pick "Ubuntu 22.04 LTS (minimal)"
5. Activate installation

### Digital Ocean
1. Create Droplet
2. Choose "Ubuntu 22.04 LTS x64"
3. Select your plan
4. Add SSH keys (recommended)
5. Create

## Post-Installation Check

After OS installation, verify your Ubuntu version:

```bash
# Check version
lsb_release -a

# Should show:
# Distributor ID: Ubuntu
# Description:    Ubuntu 22.04.3 LTS
# Release:        22.04
# Codename:       jammy

# Check kernel
uname -r
# Should show: 5.15.x.x-generic or newer
```

## Required Initial Setup

Before running the Bitcoin setup script:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git nano

# Verify you have internet
ping -c 3 google.com

# Check disk space (need 2TB+)
df -h

# Ready for Bitcoin setup!
```

## Alternative OS Options

### If Ubuntu 22.04 is not available:

1. **Ubuntu 24.04 LTS** (Noble Numbat)
   - Newer but should work
   - May need minor adjustments
   - Still LTS with 5-year support

2. **Debian 12** (Bookworm)
   - Very stable
   - Requires manual Docker installation
   - Good alternative if Ubuntu unavailable

### NOT Recommended:
- ❌ Ubuntu non-LTS versions (23.10, etc.)
- ❌ Ubuntu Desktop (unnecessary GUI)
- ❌ Older Ubuntu (20.04 or below)
- ❌ Experimental distros

## Final Setup Command

Once Ubuntu 22.04 is installed and updated:

```bash
# Download and run Bitcoin setup
cd /root
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/setup-config.env
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/setup-bitcoin-node.sh
wget https://raw.githubusercontent.com/yourusername/btcpayserver-setup/main/medampudi/bitcoin-sovereignty-setup.sh

chmod +x *.sh
nano setup-config.env  # Edit your configuration
./setup-bitcoin-node.sh
```

That's it! Ubuntu 22.04 LTS is your best choice for a stable, secure Bitcoin node.