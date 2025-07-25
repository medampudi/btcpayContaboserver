#!/bin/bash
# Simple script to check Bitcoin sync status and advise next steps

clear
echo "=== Bitcoin Sync Status Check ==="
echo "================================="
echo ""

# Check if Bitcoin is running
if ! docker ps | grep -q bitcoind; then
    echo "❌ Bitcoin Core is not running!"
    echo ""
    echo "Start it with:"
    echo "cd /opt/bitcoin && docker compose up -d bitcoind"
    exit 1
fi

# Get sync info
SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=bitcoin_rpc_user -rpcpassword=KsVsyjn1Mfu9FA0H getblockchaininfo 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "⏳ Bitcoin Core is still starting up..."
    echo "Wait a few minutes and try again."
    exit 1
fi

# Extract info
BLOCKS=$(echo $SYNC_INFO | jq -r '.blocks')
HEADERS=$(echo $SYNC_INFO | jq -r '.headers')
PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress')
PROGRESS_PCT=$(echo "scale=1; $PROGRESS * 100" | bc)

# Get peer count
PEERS=$(docker exec bitcoind bitcoin-cli -rpcuser=bitcoin_rpc_user -rpcpassword=KsVsyjn1Mfu9FA0H getconnectioncount 2>/dev/null || echo "0")

# Display status
echo "📊 Sync Progress: ${PROGRESS_PCT}%"
echo "📦 Blocks: $BLOCKS / $HEADERS"
echo "🌐 Connected Peers: $PEERS"
echo ""

# Check if ready for next step
if (( $(echo "$PROGRESS >= 0.9" | bc -l) )); then
    echo "✅ Bitcoin is synced enough (${PROGRESS_PCT}%)!"
    echo ""
    echo "You can now run the completion setup:"
    echo "👉 ./complete-bitcoin-setup.sh"
    echo ""
    echo "This will add:"
    echo "- Fulcrum (Electrum server)"
    echo "- Mempool explorer"
    echo "- BTC RPC Explorer"
    echo "- Databases"
    echo "- BTCPay Server preparation"
else
    # Calculate remaining time estimate (rough)
    if [ "$BLOCKS" -gt 0 ] && [ "$HEADERS" -gt 0 ]; then
        BLOCKS_LEFT=$((HEADERS - BLOCKS))
        # Assume ~1 block per 10 minutes average
        MINUTES_LEFT=$((BLOCKS_LEFT * 10))
        HOURS_LEFT=$((MINUTES_LEFT / 60))
        DAYS_LEFT=$((HOURS_LEFT / 24))
        
        echo "⏳ Still syncing..."
        echo ""
        echo "Estimated time remaining:"
        if [ $DAYS_LEFT -gt 0 ]; then
            echo "~$DAYS_LEFT days"
        else
            echo "~$HOURS_LEFT hours"
        fi
    fi
    echo ""
    echo "Keep waiting. Check again with:"
    echo "👉 ./check-sync.sh"
fi

echo ""
echo "View detailed logs: docker logs --tail 20 bitcoind"
echo "================================="