#!/bin/bash
# This script creates the monitoring scripts with proper escaping

# Get configuration from environment or use defaults
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecurePassword}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.example.com}"
ADMIN_USER="${ADMIN_USER:-admin}"
EMAIL="${EMAIL:-admin@example.com}"
FAMILY_NAME="${FAMILY_NAME:-Family}"

# Create scripts directory
mkdir -p /opt/bitcoin/scripts

# Create status.sh
cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
clear
echo "=== Bitcoin Sovereignty Stack Status ==="
echo "========================================"
echo ""
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
echo "Swap: $(free -h | grep Swap | awk '{print $3 " / " $2}')"
echo ""
echo "=== Disk Usage ==="
df -h | grep -E "Filesystem|/opt/bitcoin|/$" | awk '{printf "%-20s %5s %5s %5s %5s\n", $1, $2, $3, $4, $5}'
echo ""
echo "=== Bitcoin Core ==="
if command -v docker &> /dev/null && docker ps | grep -q bitcoind; then
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=__RPC_USER__ -rpcpassword=__RPC_PASS__ getblockchaininfo 2>/dev/null)
    if [ $? -eq 0 ]; then
        BLOCKS=$(echo $SYNC_INFO | jq -r '.blocks')
        HEADERS=$(echo $SYNC_INFO | jq -r '.headers')
        PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress')
        PROGRESS_PCT=$(echo "scale=2; $PROGRESS * 100" | bc)
        SIZE=$(echo $SYNC_INFO | jq -r '.size_on_disk')
        SIZE_GB=$(echo "scale=2; $SIZE / 1073741824" | bc)
        
        echo "Blocks: $BLOCKS / $HEADERS"
        echo "Sync Progress: ${PROGRESS_PCT}%"
        echo "Chain Size: ${SIZE_GB} GB"
        
        # Get peer info
        PEER_COUNT=$(docker exec bitcoind bitcoin-cli -rpcuser=__RPC_USER__ -rpcpassword=__RPC_PASS__ getconnectioncount 2>/dev/null || echo "0")
        echo "Connected Peers: $PEER_COUNT"
    else
        echo "Bitcoin Core: Starting up..."
    fi
else
    echo "Bitcoin Core: Not running"
fi
echo ""
echo "=== Docker Services ==="
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | grep -E "NAME|bitcoind|fulcrum|mempool|btc-explorer|postgres|mempool-db"
else
    echo "Docker not installed"
fi
echo ""
echo "=== Network Services ==="
echo "Firewall: $(sudo ufw status | grep Status | awk '{print $2}')"
echo "Tailscale: $(command -v tailscale &> /dev/null && (tailscale status | grep -q "Logged out" && echo "Not Connected" || echo "Connected: $(tailscale ip -4)") || echo "Not Installed")"
echo "Cloudflare: $(systemctl is-active cloudflared 2>/dev/null || echo "Not installed")"
echo ""
echo "=== Service URLs ==="
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4)
    echo "BTCPay Server: https://__BTCPAY_DOMAIN__"
    echo "Mempool Explorer: http://$TAILSCALE_IP:8080"
    echo "BTC RPC Explorer: http://$TAILSCALE_IP:3002"
    echo "Electrum Server: $TAILSCALE_IP:50001"
fi
echo ""
echo "Last updated: $(date)"
EOF

# Replace placeholders in status.sh
sed -i "s/__RPC_USER__/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/status.sh
sed -i "s/__RPC_PASS__/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/status.sh
sed -i "s/__BTCPAY_DOMAIN__/${BTCPAY_DOMAIN}/g" /opt/bitcoin/scripts/status.sh

# Create check-bitcoin.sh
cat > /opt/bitcoin/scripts/check-bitcoin.sh << 'EOF'
#!/bin/bash
if docker ps | grep -q bitcoind; then
    docker exec bitcoind bitcoin-cli \
        -rpcuser=__RPC_USER__ \
        -rpcpassword=__RPC_PASS__ \
        getblockchaininfo | jq ".chain, .blocks, .headers, (.verificationprogress * 100), (.size_on_disk / 1073741824), .pruned" | \
    (
        read chain
        read blocks
        read headers
        read progress
        read size_gb
        read pruned
        
        echo "{"
        echo "  \"chain\": $chain,"
        echo "  \"blocks\": $blocks,"
        echo "  \"headers\": $headers,"
        echo "  \"progress\": \"${progress}%\","
        echo "  \"size_gb\": \"${size_gb} GB\","
        echo "  \"pruned\": $pruned"
        echo "}"
    )
else
    echo "Bitcoin Core is not running"
fi
EOF

# Replace placeholders
sed -i "s/__RPC_USER__/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/check-bitcoin.sh
sed -i "s/__RPC_PASS__/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/check-bitcoin.sh

# Create access-info.sh
cat > /opt/bitcoin/scripts/access-info.sh << 'EOF'
#!/bin/bash
echo "=== Bitcoin Stack Access Information ==="
echo "======================================="
echo ""
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4)
    echo "=== Private Services (via Tailscale) ==="
    echo "Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "Mempool Explorer:    http://$TAILSCALE_IP:8080"
    echo "BTC RPC Explorer:    http://$TAILSCALE_IP:3002"
    echo "Lightning Dashboard: http://$TAILSCALE_IP:3000"
    echo ""
    echo "Electrum Server:     $TAILSCALE_IP:50001 (TCP)"
    echo "Electrum Server SSL: $TAILSCALE_IP:50002 (SSL)"
    echo "Bitcoin RPC:         $TAILSCALE_IP:8332"
    echo ""
    echo "SSH Access:          ssh __ADMIN_USER__@$TAILSCALE_IP"
else
    echo "Tailscale not connected. Please run: tailscale up"
fi
echo ""
echo "=== Public Services ==="
echo "BTCPay Server:       https://__BTCPAY_DOMAIN__"
echo ""
echo "=== Wallet Configuration ==="
echo "For Electrum, Sparrow, or other wallets:"
echo "Server: [Your Tailscale IP]"
echo "Port: 50001 (TCP) or 50002 (SSL)"
echo "No proxy needed within Tailscale network"
EOF

# Replace placeholders
sed -i "s/__ADMIN_USER__/${ADMIN_USER}/g" /opt/bitcoin/scripts/access-info.sh
sed -i "s/__BTCPAY_DOMAIN__/${BTCPAY_DOMAIN}/g" /opt/bitcoin/scripts/access-info.sh

# Create backup.sh
cat > /opt/bitcoin/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/bitcoin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/opt/bitcoin/logs/backup.log"

# Create directories
mkdir -p $BACKUP_DIR
mkdir -p $(dirname $LOG_FILE)

echo "[$(date)] Starting backup..." >> $LOG_FILE

# Backup configurations
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz \
    /opt/bitcoin/configs \
    /opt/bitcoin/docker-compose.yml \
    /opt/bitcoin/scripts \
    2>> $LOG_FILE

# Backup BTCPay data if exists
if [ -d "/opt/bitcoin/btcpay" ]; then
    cd /opt/bitcoin/btcpay/btcpayserver-docker
    if [ -f "./btcpay-backup.sh" ]; then
        ./btcpay-backup.sh $BACKUP_DIR/btcpay_$DATE.tar.gz >> $LOG_FILE 2>&1
    fi
fi

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "[$(date)] Backup completed" >> $LOG_FILE
echo "Backup completed: $DATE"
EOF

# Create health-check.sh
cat > /opt/bitcoin/scripts/health-check.sh << 'EOF'
#!/bin/bash
ALERT_EMAIL="__EMAIL__"
LOG_FILE="/opt/bitcoin/logs/health-check.log"

mkdir -p $(dirname $LOG_FILE)

# Check critical services
CRITICAL_SERVICES=("bitcoind" "fulcrum" "mempool-api")
ISSUES=""

for service in "${CRITICAL_SERVICES[@]}"; do
    if ! docker ps | grep -q $service; then
        ISSUES="$ISSUES\n- Service $service is not running"
    fi
done

# Check disk space
DISK_USAGE=$(df -h /opt/bitcoin | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    ISSUES="$ISSUES\n- Disk usage critical: ${DISK_USAGE}%"
fi

# Send alert if issues found
if [ -n "$ISSUES" ]; then
    echo -e "Bitcoin Node Alert!\n$ISSUES" | mail -s "Bitcoin Node Issues - $(hostname)" $ALERT_EMAIL
    echo "[$(date)] Issues found: $ISSUES" >> $LOG_FILE
fi
EOF

sed -i "s/__EMAIL__/${EMAIL}/g" /opt/bitcoin/scripts/health-check.sh

# Create family-status.sh
cat > /opt/bitcoin/scripts/family-status.sh << 'EOF'
#!/bin/bash
clear
echo "=== __FAMILY_NAME__ Bitcoin Status ==="
echo "===================================="
echo ""
echo "📊 Bitcoin Price: $(curl -s https://api.coinbase.com/v2/exchange-rates?currency=BTC | jq -r '.data.rates.INR' | xargs printf "₹%'"'"'.0f\n" 2>/dev/null || echo "Loading...")"
echo ""
echo "⚡ Network Status:"
if docker ps | grep -q bitcoind; then
    SYNC=$(docker exec bitcoind bitcoin-cli -rpcuser=__RPC_USER__ -rpcpassword=__RPC_PASS__ getblockchaininfo 2>/dev/null | jq -r '.verificationprogress' || echo "0")
    if [ -n "$SYNC" ] && [ "$SYNC" != "0" ]; then
        SYNC_PCT=$(echo "scale=0; $SYNC * 100 / 1" | bc)
        echo "Sync Progress: ${SYNC_PCT}% ✅"
    fi
fi
echo ""
echo "🔗 Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "bitcoind|mempool|btcpay" | sed 's/bitcoind/Bitcoin Core/g' | sed 's/mempool-web/Blockchain Explorer/g' | sed 's/btcpayserver/Payment Processor/g'
echo ""
echo "👨‍👩‍👧‍👦 Family Access:"
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    echo "✅ VPN Connected"
    echo "📱 Wallet Server: $(tailscale ip -4):50001"
else
    echo "❌ VPN Not Connected"
fi
EOF

# Replace placeholders
sed -i "s/__FAMILY_NAME__/${FAMILY_NAME}/g" /opt/bitcoin/scripts/family-status.sh
sed -i "s/__RPC_USER__/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/family-status.sh
sed -i "s/__RPC_PASS__/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/family-status.sh

# Make all scripts executable
chmod +x /opt/bitcoin/scripts/*.sh

echo "✅ All monitoring scripts created successfully!"
echo "Scripts are located in: /opt/bitcoin/scripts/"