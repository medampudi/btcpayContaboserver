# Fresh Ubuntu 22.04 Bitcoin Node Installation Guide

## Essential Files Only

For a completely fresh installation on Ubuntu 22.04, you only need **3 files**:

### 1. `bitcoin-node-setup.sh`
The main consolidated script that handles everything

### 2. `setup-config-template.env`  
Template configuration file to customize

### 3. This guide

## Step-by-Step Fresh Installation

### 1. Prepare Ubuntu 22.04 Server

```bash
# Login to your fresh Ubuntu 22.04 server
ssh ubuntu@your-server-ip

# Switch to root
sudo su -
```

### 2. Download Required Files

```bash
# Create working directory
mkdir -p /root/bitcoin-setup
cd /root/bitcoin-setup

# Download the two essential files
wget https://raw.githubusercontent.com/your-repo/bitcoin-node-setup.sh
wget https://raw.githubusercontent.com/your-repo/setup-config-template.env

# Make script executable
chmod +x bitcoin-node-setup.sh
```

### 3. Configure Your Settings

```bash
# Copy template to actual config
cp setup-config-template.env setup-config.env

# Edit with your values
nano setup-config.env
```

**Must change**:
- `DOMAIN_NAME="your-actual-domain.com"`
- `EMAIL="your-email@example.com"`
- All passwords (avoid #, =, +, / characters)
- `TAILSCALE_AUTHKEY="tskey-auth-..."` (from Tailscale admin)

**Optional**:
- Cloudflare API tokens (for automated tunnel)
- Server specs adjustments (RAM, connections)

### 4. Run the Setup

```bash
# Execute the setup (will take 20-30 minutes)
./bitcoin-node-setup.sh
```

The script will:
1. Update system and install packages
2. Create admin user
3. Setup security (firewall, fail2ban)
4. Install Docker
5. Connect Tailscale VPN
6. Start Bitcoin Core
7. Create monitoring scripts

### 5. Wait for Bitcoin Sync

```bash
# Check sync progress (run every few hours)
/opt/bitcoin/scripts/check-sync.sh
```

Bitcoin Core needs to sync the entire blockchain (2-5 days).

### 6. Complete Setup

When sync reaches 90%+:

```bash
# Enable all services
/opt/bitcoin/scripts/enable-all-services.sh
```

## That's It!

Your Bitcoin sovereignty stack is now running with:
- ✅ Bitcoin Full Node
- ✅ Lightning Network
- ✅ BTCPay Server  
- ✅ Mempool Explorer
- ✅ Electrum Server
- ✅ Secure VPN Access

## Access Your Services

1. Connect to Tailscale VPN on your device
2. Access services:
   - Mempool: `http://[tailscale-ip]:8080`
   - Explorer: `http://[tailscale-ip]:3002`
   - BTCPay: `https://pay.your-domain.com`

## Minimal File Count

The beauty of this setup is its simplicity:
- **2 files** to download
- **1 config** to edit
- **1 command** to run

Everything else is automated!

## Server Requirements

**Minimum** (Family use):
- Ubuntu 22.04 LTS
- 16GB RAM
- 2TB Storage
- 100Mbps connection

**Recommended** (Business use):
- Ubuntu 22.04 LTS  
- 32GB RAM
- 4TB SSD Storage
- 1Gbps connection

## Security Notes

- All internal services are VPN-only (Tailscale)
- BTCPay Server is the only public service
- Daily automated backups
- Firewall + Fail2ban protection

---

*This guide represents the culmination of extensive testing and debugging, condensed into the simplest possible deployment process.*