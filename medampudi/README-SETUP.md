# Bitcoin Sovereignty Setup Guide - Medampudi

## ✅ Current Status

Your Bitcoin node is now running! Here's what's set up:

- **User**: rajesh (group: admin)
- **Tailscale IP**: 100.111.219.39
- **Bitcoin Core**: Running and syncing
- **Domain**: simbotix.com
- **BTCPay Domain**: pay.simbotix.com

## 📊 Monitor Bitcoin Sync Progress

```bash
# Check sync status
cd /opt/bitcoin && ./scripts/status.sh

# Watch Bitcoin logs
docker logs -f bitcoind

# Check sync percentage only
docker exec bitcoind bitcoin-cli -rpcuser=bitcoin_rpc_user -rpcpassword=KsVsyjn1Mfu9FA0H getblockchaininfo | jq -r '.verificationprogress * 100 | floor'
```

Bitcoin sync will take **2-5 days** depending on your internet speed.

## 🚀 After Bitcoin Syncs (90%+)

Once Bitcoin reaches 90% sync, run the completion script to add all other services:

```bash
cd /root
./complete-bitcoin-setup.sh
```

This will add:
- **Fulcrum**: Electrum server for wallets
- **Mempool**: Beautiful blockchain explorer
- **BTC RPC Explorer**: Alternative explorer
- **Databases**: PostgreSQL and MariaDB
- **BTCPay Server**: Payment processor setup

## 📁 Important Files

### Configuration
- `setup-config.env` - Your configuration (passwords, domains, etc.)
- `/opt/bitcoin/docker-compose.yml` - Docker services configuration
- `/opt/bitcoin/configs/` - Service configurations

### Scripts
- `quick-fix-continue.sh` - The script that fixed and continued setup
- `complete-bitcoin-setup.sh` - Run after Bitcoin syncs to add all services
- `/opt/bitcoin/scripts/status.sh` - Check system status

### Data Locations
- `/opt/bitcoin/data/bitcoin/` - Bitcoin blockchain data
- `/opt/bitcoin/data/fulcrum/` - Electrum server data (after completion)
- `/opt/bitcoin/logs/` - Application logs
- `/opt/bitcoin/backups/` - Backup location

## 🔐 Access Information

### Via Tailscale (Private - Family Only)
All services are private and only accessible through Tailscale VPN:

- **SSH**: `ssh rajesh@100.111.219.39`
- **Bitcoin RPC**: `100.111.219.39:8332`
- **Electrum Server**: `100.111.219.39:50001` (after completion)
- **Mempool Explorer**: `http://100.111.219.39:8080` (after completion)
- **BTC RPC Explorer**: `http://100.111.219.39:3002` (after completion)

### Public Access
Only BTCPay Server will be publicly accessible (after setup):
- **BTCPay**: `https://pay.simbotix.com`

## 👨‍👩‍👧‍👦 Family Access Setup

To give family members access:

1. **Install Tailscale** on their device
2. **Share your network**:
   - Go to https://login.tailscale.com/admin/users
   - Click "Invite users"
   - Send invite to family member
3. **Configure their wallet**:
   - Server: `100.111.219.39`
   - Port: `50001`
   - No SSL needed

## 🛠️ Maintenance Commands

```bash
# Check all services
docker ps

# Restart Bitcoin if needed
cd /opt/bitcoin
docker compose restart bitcoind

# Update services
docker compose pull
docker compose up -d

# Check disk space
df -h /opt/bitcoin

# Backup (after full setup)
/opt/bitcoin/scripts/backup.sh
```

## ⚠️ Important Notes

1. **Do NOT interrupt Bitcoin sync** - Let it complete
2. **Keep Tailscale connected** - It's your secure access
3. **Save your passwords** - They're in setup-config.env
4. **Regular backups** - Will auto-run daily after full setup

## 📞 Troubleshooting

If Bitcoin stops syncing:
```bash
# Check if it's running
docker ps | grep bitcoind

# Check logs for errors
docker logs --tail 50 bitcoind

# Restart if needed
docker compose restart bitcoind
```

If Tailscale disconnects:
```bash
tailscale status
tailscale up
```

## 🎯 Next Steps Timeline

1. **Now**: Monitor Bitcoin sync progress
2. **In 2-5 days**: When sync reaches 90%, run `./complete-bitcoin-setup.sh`
3. **After completion**: 
   - Setup family wallets
   - Configure BTCPay Store
   - Start accepting Bitcoin payments!

---

**Remember**: You're building your own Bitcoin bank. Once complete, you'll have full financial sovereignty with no third parties involved!