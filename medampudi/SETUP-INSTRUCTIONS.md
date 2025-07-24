# 🚀 OVH Bitcoin Setup - Step by Step Guide

## Prerequisites
1. OVH server with Ubuntu 24.04 installed
2. SSH access to your server as `ubuntu` user
3. Your domain name (e.g., bitcoin.yourdomain.com)
4. Tailscale account (free at https://tailscale.com)
5. Cloudflare account with your domain added

## Step 1: Download the Setup Script

SSH into your OVH server:
```bash
ssh ubuntu@YOUR_OVH_SERVER_IP
```

Download the setup script:
```bash
wget https://raw.githubusercontent.com/medampudi/btcpayContaboserver/main/medampudi/COMPLETE-OVH-SETUP.sh
chmod +x COMPLETE-OVH-SETUP.sh
```

## Step 2: Edit Configuration

Open the script in an editor:
```bash
nano COMPLETE-OVH-SETUP.sh
```

Find the CONFIGURATION section at the top and change these values:

```bash
DOMAIN_NAME="your-actual-domain.com"              # e.g., medampudi.com
BTCPAY_DOMAIN="pay.your-actual-domain.com"        # e.g., pay.medampudi.com
EMAIL="your-email@gmail.com"                      # Your email

# Change ALL passwords to strong ones:
BITCOIN_RPC_PASS="YourStrongPassword123!"
POSTGRES_PASS="AnotherStrongPassword456!"
MARIADB_ROOT_PASS="RootPassword789!"
MARIADB_MEMPOOL_PASS="MempoolPassword321!"

# Get Tailscale auth key:
# 1. Go to https://login.tailscale.com/admin/settings/keys
# 2. Click "Generate auth key"
# 3. Copy and paste it here:
TAILSCALE_AUTHKEY="tskey-auth-xxxxx-xxxxxxxxx"
```

Save and exit (Ctrl+X, then Y, then Enter).

## Step 3: Run the Setup

Execute the script:
```bash
./COMPLETE-OVH-SETUP.sh
```

The script will:
- Install all required software
- Set up Docker and all Bitcoin services
- Configure security (firewall, fail2ban)
- Start all services

**This takes about 30-45 minutes to complete.**

## Step 4: Connect Tailscale (if not automatic)

If Tailscale didn't connect automatically:
```bash
sudo tailscale up
```

Follow the URL it gives you to authenticate.

## Step 5: Setup Cloudflare Tunnel (for BTCPay)

1. Login to Cloudflare:
```bash
cloudflared tunnel login
```

2. Create tunnel:
```bash
cloudflared tunnel create medampudi-bitcoin
```

3. Route your domain:
```bash
cloudflared tunnel route dns medampudi-bitcoin pay.yourdomain.com
```

4. Start the tunnel:
```bash
cd /opt/bitcoin
cloudflared tunnel run --config configs/cloudflare-tunnel.yml medampudi-bitcoin
```

## Step 6: Check Status

Monitor Bitcoin sync progress:
```bash
cd /opt/bitcoin
./scripts/status.sh
```

Bitcoin will take 2-3 days to fully sync. You can use other services immediately.

## Step 7: Access Your Services

Get your access URLs:
```bash
./scripts/access-info.sh
```

### Via Tailscale (Private Services):
- Mempool Explorer: http://[TAILSCALE_IP]:8080
- Bitcoin Explorer: http://[TAILSCALE_IP]:3002
- Lightning Manager: http://[TAILSCALE_IP]:3000
- Electrum Server: [TAILSCALE_IP]:50001

### Public Access:
- BTCPay Server: https://pay.yourdomain.com

## Family Setup

### For Family Members:
1. Install Tailscale on their device
2. Share your Tailscale network with them
3. They can access all private services through Tailscale

### Mobile Wallet Setup:
- Use any Electrum-compatible wallet
- Server: [Your Tailscale IP]
- Port: 50001
- No SSL required within Tailscale

## Maintenance

### Daily Status Check:
```bash
cd /opt/bitcoin && ./scripts/status.sh
```

### Backup (runs automatically at 3 AM):
```bash
./scripts/backup.sh
```

### View Logs:
```bash
# Bitcoin logs
docker logs bitcoind

# BTCPay logs
docker logs btcpayserver

# All services
docker ps
```

## Troubleshooting

### If services aren't starting:
```bash
cd /opt/bitcoin
docker compose down
docker compose up -d
```

### Check specific service:
```bash
docker logs [service-name]
# e.g., docker logs bitcoind
```

### Restart everything:
```bash
cd /opt/bitcoin
docker compose restart
```

## Security Notes

1. **SSH Access**: After Tailscale is working, consider restricting SSH to Tailscale only
2. **Backups**: Critical wallet backups are in `/opt/bitcoin/backups`
3. **Firewall**: Only required ports are open (80, 443, 8333, 9735)
4. **Updates**: Run `apt update && apt upgrade` regularly

## Support

If you need help:
1. Check service logs: `docker logs [service-name]`
2. Run status check: `./scripts/status.sh`
3. Verify Tailscale connection: `tailscale status`

---

**🎉 Congratulations! Your family Bitcoin infrastructure is set up!**

You're now running:
- Full Bitcoin Node
- BTCPay Server for payments
- Lightning Network node
- Mempool explorer
- Electrum server for wallets
- All secured with Tailscale VPN

Monthly cost: $34 (saving $20/month from Contabo!)