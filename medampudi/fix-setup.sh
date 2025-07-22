#!/bin/bash
# Quick fix for the setup.sh script

echo "🔧 Fixing setup.sh script syntax errors..."

# Fix the heredoc issues
sed -i "s/cat > scripts\/bitcoin-status.sh << 'EOF'/cat > scripts\/bitcoin-status.sh << EOF/g" setup.sh
sed -i "s/cat > scripts\/family-access.sh << 'EOF'/cat > scripts\/family-access.sh << EOF/g" setup.sh
sed -i "s/cat > scripts\/migrate-from-contabo.sh << 'EOF'/cat > scripts\/migrate-from-contabo.sh << EOF/g" setup.sh

# Escape the $ signs that should be literal in the scripts
sed -i 's/\$BITCOIN_RPC_USER/\\\$BITCOIN_RPC_USER/g' setup.sh
sed -i 's/\$BITCOIN_RPC_PASS/\\\$BITCOIN_RPC_PASS/g' setup.sh
sed -i 's/\$CONTABO_IP/\\\$CONTABO_IP/g' setup.sh
sed -i 's/\$CONTABO_USER/\\\$CONTABO_USER/g' setup.sh

# But keep the ones that should expand
sed -i 's/\\\$BTCPAY_DOMAIN/\$BTCPAY_DOMAIN/g' setup.sh
sed -i 's/\\\$TAILSCALE_IP/\$TAILSCALE_IP/g' setup.sh

echo "✅ Script fixed! You can now run ./setup.sh"