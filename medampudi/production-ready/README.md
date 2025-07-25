# Bitcoin Node Setup - Ubuntu User Version

## 🚀 Quick Start for Ubuntu 22.04

This production-ready Bitcoin sovereignty setup follows security best practices by running as the standard Ubuntu user instead of root.

### Prerequisites

- Ubuntu 22.04 LTS (recommended) or 24.04 LTS
- Minimum 16GB RAM, 2TB storage
- SSH access as `ubuntu` user
- Domain name (for BTCPay Server)
- Tailscale account for VPN access

### Setup Steps

1. **Login as ubuntu user** (standard for cloud providers):
   ```bash
   ssh ubuntu@your-server-ip
   # Stay as ubuntu user - no sudo su needed!
   ```

2. **Download the required files**:
   ```bash
   # Download setup script and config template
   wget https://your-repo/bitcoin-node-setup.sh
   wget https://your-repo/setup-config-template.env
   
   # Make script executable
   chmod +x bitcoin-node-setup.sh
   ```

3. **Configure your settings**:
   ```bash
   cp setup-config-template.env setup-config.env
   nano setup-config.env
   ```
   
   Update these critical values:
   - `DOMAIN_NAME` - Your domain
   - `EMAIL` - Your email
   - All passwords (avoid #, =, +, / characters)
   - `TAILSCALE_AUTHKEY` - Get from Tailscale admin panel
   - Cloudflare tokens (optional)

4. **Run the setup**:
   ```bash
   ./bitcoin-node-setup.sh
   # Script uses sudo only when needed for system changes
   ```

5. **Important: Re-login for Docker access**:
   ```bash
   exit
   ssh ubuntu@your-server-ip
   ```

6. **Monitor Bitcoin sync** (takes 2-5 days):
   ```bash
   ~/bitcoin-node/scripts/check-sync.sh
   ```

7. **Complete setup** when sync reaches 90%:
   ```bash
   ~/bitcoin-node/scripts/enable-all-services.sh
   ```

## 📁 Directory Structure

Everything lives in your home directory - no root access needed!

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

## 📁 What Gets Installed

- **Bitcoin Core** - Full node
- **Fulcrum** - Electrum server
- **BTCPay Server** - Payment processor
- **Lightning Network** - Fast payments
- **Mempool** - Blockchain explorer
- **BTC RPC Explorer** - Additional explorer
- **PostgreSQL & MariaDB** - Databases
- **Tailscale VPN** - Secure remote access

## 🔐 Security Improvements

- ✅ **No Root Login**: SSH root access disabled
- ✅ **User Isolation**: Services run as ubuntu user
- ✅ **Selective Sudo**: Only system changes need privileges
- ✅ **Docker Security**: User in docker group, not running as root
- ✅ **Firewall**: UFW configured with minimal ports
- ✅ **Fail2ban**: Intrusion prevention active
- ✅ **VPN Only**: Internal services only via Tailscale

## 📍 Service Access (via Tailscale)

Once connected to Tailscale, access services at:
- Mempool: `http://[tailscale-ip]:8080`
- BTC Explorer: `http://[tailscale-ip]:3002`
- Electrum: `[tailscale-ip]:50001`
- BTCPay: `https://pay.your-domain.com` (public)

## 🛠️ Daily Management

All without sudo or root access:

### Check Status
```bash
~/bitcoin-node/scripts/status.sh
```

### View Logs
```bash
docker logs -f bitcoind
docker logs -f fulcrum
docker logs -f btcpayserver
```

### Restart Services
```bash
cd ~/bitcoin-node
docker compose restart bitcoind
```

### Edit Configuration
```bash
nano ~/bitcoin-node/setup-config.env
```

### Manual Backup
```bash
~/bitcoin-node/scripts/backup.sh
```

## 📝 Configuration Reference

The `setup-config.env` file contains all settings:

- **Server Settings**: Hostname, timezone, swap size
- **Security**: SSH port configuration
- **Passwords**: Database and RPC passwords
- **API Keys**: Tailscale and Cloudflare
- **Performance**: Bitcoin cache and connection limits

## 🚨 Troubleshooting

### Can't run docker commands?
```bash
# You need to re-login after setup for group membership
exit
ssh ubuntu@your-server-ip
```

### Permission denied?
```bash
# Check file ownership - should be ubuntu:ubuntu
ls -la ~/bitcoin-node/
```

### Bitcoin won't start?
```bash
# Check disk space
df -h

# Check logs
docker logs bitcoind

# Verify config
cat ~/bitcoin-node/setup-config.env
```

### Sync is slow?
- Normal: 2-5 days for full sync
- Check peers: `docker exec bitcoind bitcoin-cli getpeerinfo | jq length`
- Ensure good internet connection

## 💡 Why Ubuntu User Instead of Root?

1. **Security**: Follows principle of least privilege
2. **Standards**: Industry best practice for servers
3. **Cloud Ready**: Works with AWS, Azure, GCP defaults
4. **Easier Management**: No sudo for routine tasks
5. **Safer**: Limits damage from mistakes or breaches

## 📊 System Requirements

**Minimum** (Family use):
- Ubuntu 22.04 LTS
- 16GB RAM
- 2TB storage
- 100Mbps internet

**Recommended** (Business use):
- Ubuntu 22.04 LTS
- 32GB RAM
- 4TB NVMe SSD
- 1Gbps internet

## 🎯 Key Features

- **Single Script**: One script handles everything
- **Resume Capable**: Can continue from interruptions
- **Auto Backups**: Daily at 3 AM
- **Systemd Service**: Auto-starts on boot
- **Health Monitoring**: Built-in status scripts
- **Family Friendly**: Easy to manage and understand

## 📞 Support Resources

- **Setup Issues**: Check error messages and logs
- **Common Problems**: See troubleshooting section
- **Bitcoin Sync**: Use check-sync.sh script
- **Service Status**: Use status.sh script

---

*This setup creates a secure, production-ready Bitcoin sovereignty stack following Linux security best practices.*