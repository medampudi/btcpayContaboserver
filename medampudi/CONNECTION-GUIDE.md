# OVH Server Connection Guide

## How to Connect and Run the Setup

### 1. Connect to Your OVH Server

From your Mac, open Terminal and connect:
```bash
ssh -i /Volumes/ED02/illu/.ssh/btcpayserver-ovhcloud ubuntu@51.91.67.79
```

### 2. Download and Run the Setup Script

```bash
# Download the script
wget https://raw.githubusercontent.com/your-repo/btcpayContaboserver/main/medampudi/COMPLETE-OVH-SETUP.sh

# Make it executable
chmod +x COMPLETE-OVH-SETUP.sh

# Run the setup
./COMPLETE-OVH-SETUP.sh
```

### 3. If You Get Permission Errors

The script handles docker permissions automatically, but if you see "permission denied" errors:

```bash
# Log out and back in (this refreshes group membership)
exit
ssh -i /Volumes/ED02/illu/.ssh/btcpayserver-ovhcloud ubuntu@51.91.67.79

# Or run specific commands with sudo if needed
sudo docker ps
```

### 4. Monitor the Setup Progress

The script will take 30-60 minutes to complete. You can monitor:
```bash
# Check if script is still running
ps aux | grep COMPLETE-OVH-SETUP

# Check docker services
sudo docker ps

# Check logs of specific service
sudo docker logs bitcoind
sudo docker logs btcpayserver
```

### 5. After Setup Completes

```bash
# Check status
cd /opt/bitcoin
./scripts/status.sh

# Get family access information
./scripts/access-info.sh

# Check Bitcoin sync progress
sudo docker exec bitcoind bitcoin-cli getblockchaininfo
```

### 6. Troubleshooting Common Issues

**If services fail to start:**
```bash
cd /opt/bitcoin
sudo docker compose logs
sudo docker compose restart [service-name]
```

**If Tailscale connection fails:**
```bash
sudo tailscale up --authkey=YOUR_AUTH_KEY --hostname="medampudi-bitcoin-ovh"
```

**If you need to restart everything:**
```bash
cd /opt/bitcoin
sudo docker compose down
sudo docker compose up -d
```

### 7. Setting Up Cloudflare Tunnel (After Bitcoin Sync)

```bash
# Login to Cloudflare
cloudflared tunnel login

# Create the tunnel
cloudflared tunnel create medampudi-bitcoin

# Route DNS
cloudflared tunnel route dns medampudi-bitcoin pay.simbotix.com

# Start the tunnel
cloudflared tunnel run medampudi-bitcoin
```

## Key Files Location

- Main setup: `/opt/bitcoin/`
- Configuration: `/opt/bitcoin/configs/`
- Scripts: `/opt/bitcoin/scripts/`
- Docker compose: `/opt/bitcoin/docker-compose.yml`

## Important Notes

1. **Bitcoin sync takes 2-3 days** - Be patient!
2. **Only BTCPay Server is public** - Other services only via Tailscale
3. **Backup your keys** - Run `/opt/bitcoin/scripts/backup.sh` regularly
4. **Check logs** if something doesn't work: `sudo docker logs [container-name]`

## Getting Help

If you encounter issues:
1. Check the logs: `sudo docker compose logs`
2. Verify services: `sudo docker ps`
3. Check disk space: `df -h`
4. Restart services: `sudo docker compose restart`