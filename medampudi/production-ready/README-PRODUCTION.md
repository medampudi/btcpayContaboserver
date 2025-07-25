# Bitcoin Node Setup - Production Ready

## 🚀 Quick Start for Ubuntu 22.04

This is the cleaned-up, production-ready Bitcoin sovereignty setup that incorporates all learnings from the initial deployment.

### Prerequisites

- Ubuntu 22.04 LTS (recommended) or 24.04 LTS
- Minimum 16GB RAM, 2TB storage
- Root access to the server
- Domain name (for BTCPay Server)
- Tailscale account for VPN access

### Setup Steps

1. **Login as root** (or use `sudo su -`):
   ```bash
   ssh ubuntu@your-server-ip
   sudo su -
   ```

2. **Copy the required files**:
   ```bash
   # Option A: If you have this repository
   cp bitcoin-node-setup.sh setup-config-template.env /root/
   
   # Option B: Download directly
   wget https://your-repo/bitcoin-node-setup.sh
   wget https://your-repo/setup-config-template.env
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
   chmod +x bitcoin-node-setup.sh
   ./bitcoin-node-setup.sh
   ```

5. **Monitor Bitcoin sync** (takes 2-5 days):
   ```bash
   /opt/bitcoin/scripts/check-sync.sh
   ```

6. **Complete setup** when sync reaches 90%:
   ```bash
   /opt/bitcoin/scripts/enable-all-services.sh
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

## 🔐 Security Model

- All services except BTCPay are only accessible via Tailscale VPN
- BTCPay Server exposed publicly via Cloudflare Tunnel
- Firewall configured with minimal open ports
- Fail2ban for intrusion prevention
- Daily automated backups

## 📍 Service Access (via Tailscale)

Once connected to Tailscale, access services at:
- Mempool: `http://[tailscale-ip]:8080`
- BTC Explorer: `http://[tailscale-ip]:3002`
- Electrum: `[tailscale-ip]:50001`

## 🛠️ Maintenance

### Check Status
```bash
/opt/bitcoin/scripts/status.sh
```

### View Logs
```bash
docker logs -f bitcoind
docker logs -f fulcrum
docker logs -f btcpayserver
```

### Backup Recovery
Backups are in `/opt/bitcoin/backups/` and run daily at 3 AM.

### Updates
```bash
cd /opt/bitcoin
docker compose pull
docker compose up -d
```

## 📝 Configuration Reference

The `setup-config.env` file contains all settings. Key parameters:

- `ADMIN_USER` - Admin username (default: ubuntu)
- `BITCOIN_DBCACHE` - RAM for Bitcoin (25% of total)
- `BITCOIN_MAX_CONNECTIONS` - Peer connections
- `TAILSCALE_AUTHKEY` - For automated VPN setup

## 🚨 Troubleshooting

### Bitcoin won't start
- Check disk space: `df -h`
- Check logs: `docker logs bitcoind`
- Verify config: `cat setup-config.env`

### Can't access services
- Verify Tailscale connected: `tailscale status`
- Check firewall: `ufw status`
- Ensure services running: `docker ps`

### Sync is slow
- Normal: 2-5 days for full sync
- Check peers: `docker exec bitcoind bitcoin-cli getpeerinfo | jq length`
- Verify internet speed

## 💡 Key Learnings Applied

This setup incorporates fixes for:
- User/group permission issues
- Bitcoin RPC password restrictions  
- Docker Compose syntax compatibility
- Proper service dependencies
- Network isolation and security

The script is idempotent and can resume from interruptions.

## 📞 Support

For issues specific to this setup, check:
- `LEARNINGS-SUMMARY.md` - Common issues and solutions
- `/opt/bitcoin/logs/` - Application logs
- `docker logs [container]` - Container-specific logs

---

*This setup creates a production-ready, family-friendly Bitcoin sovereignty stack with security best practices.*