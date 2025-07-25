# Ubuntu 22.04 Bitcoin Node - Standard User Installation

## 🎯 Clean, Secure Setup Without Root

This guide uses the standard `ubuntu` user that comes with Ubuntu 22.04. No need for `sudo su -` or running everything as root!

## Prerequisites

- Ubuntu 22.04 LTS server
- You can SSH in as `ubuntu` user
- 16GB+ RAM, 2TB+ storage
- Domain name for BTCPay Server

## Quick Start (3 Files Only)

### 1. Connect to Your Server
```bash
# SSH as ubuntu user (standard for cloud providers)
ssh ubuntu@your-server-ip

# Stay as ubuntu user - no sudo su needed!
pwd  # Should show /home/ubuntu
```

### 2. Download Setup Files
```bash
# Get the setup script and config template
wget https://raw.githubusercontent.com/your-repo/bitcoin-node-setup-ubuntu.sh
wget https://raw.githubusercontent.com/your-repo/setup-config-ubuntu-template.env

# Make script executable
chmod +x bitcoin-node-setup-ubuntu.sh
```

### 3. Configure Your Settings
```bash
# Create your config from template
cp setup-config-ubuntu-template.env setup-config.env

# Edit with your values
nano setup-config.env
```

**Essential changes**:
- `DOMAIN_NAME` - Your actual domain
- `EMAIL` - Your email address
- All passwords (avoid #, =, +, /)
- `TAILSCALE_AUTHKEY` - From Tailscale admin panel

### 4. Run the Setup
```bash
# Run as ubuntu user (script will use sudo when needed)
./bitcoin-node-setup-ubuntu.sh
```

The script will:
- ✅ Use sudo only for system-level changes
- ✅ Install everything in your home directory
- ✅ Set up proper permissions
- ✅ Configure security without root access
- ✅ Create systemd service for auto-start

### 5. Post-Installation

**Important**: Log out and back in for docker group access
```bash
exit
ssh ubuntu@your-server-ip
```

**Check Bitcoin sync progress**:
```bash
~/bitcoin-node/scripts/check-sync.sh
```

**After 90% sync, enable all services**:
```bash
~/bitcoin-node/scripts/enable-all-services.sh
```

## 📁 Where Everything Lives

All in your home directory - no root access needed!

```
/home/ubuntu/
├── bitcoin-node/
│   ├── docker-compose.yml   # Service definitions
│   ├── setup-config.env     # Your configuration
│   ├── configs/             # Service configs
│   ├── scripts/             # Management scripts
│   ├── data/               # Blockchain data
│   ├── backups/            # Automatic backups
│   └── logs/               # Application logs
└── .bitcoin/
    └── .tailscale_ip       # Your Tailscale IP
```

## 🔐 Security Benefits

1. **No Root SSH**: Root login disabled
2. **User Isolation**: Services run as ubuntu user
3. **Selective Sudo**: Only system changes need privileges
4. **Docker Security**: User in docker group, not root
5. **File Permissions**: You own all your Bitcoin data

## 🛠️ Daily Management

All without sudo!

```bash
# Check status
~/bitcoin-node/scripts/status.sh

# View logs
docker logs bitcoind
docker logs btcpayserver

# Edit configuration
nano ~/bitcoin-node/setup-config.env

# Restart services
cd ~/bitcoin-node
docker compose restart bitcoind
```

## 🚀 Why This is Better

### Old Way (Root)
```bash
sudo su -                    # Dangerous!
cd /opt/bitcoin             # Root-owned
./setup.sh                  # Everything as root
sudo nano /opt/bitcoin/...  # Need sudo for everything
```

### New Way (Ubuntu User)
```bash
# Stay as ubuntu user        # Safer!
cd ~/bitcoin-node           # You own it
./scripts/status.sh         # No sudo needed
nano setup-config.env       # Direct access
```

## 📊 System Requirements

**Minimum**:
- Ubuntu 22.04 LTS
- 16GB RAM
- 2TB storage (SSD preferred)
- 100Mbps internet

**Recommended**:
- Ubuntu 22.04 LTS
- 32GB RAM
- 4TB NVMe SSD
- 1Gbps internet

## 🔍 Troubleshooting

### Can't run docker commands?
```bash
# Log out and back in for group membership
exit
ssh ubuntu@your-server-ip
```

### Permission denied?
```bash
# Check file ownership
ls -la ~/bitcoin-node/

# Should show ubuntu:ubuntu, not root:root
```

### Need to run as root for some reason?
```bash
# Use sudo for specific commands only
sudo systemctl status bitcoin-node
```

## 🎉 Summary

- **2 files** to download
- **1 config** to edit  
- **0 times** you need to be root
- **100%** more secure!

The setup respects Linux security best practices while remaining user-friendly. Your Bitcoin sovereignty without compromising security!