#!/bin/bash
# Fix Bitcoin RPC password issue (# character not allowed)

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Load current config
if [[ -f "setup-config.env" ]]; then
    source setup-config.env
fi

log_info "Fixing Bitcoin RPC password issue..."
echo ""
log_warning "The password contains '#' which Bitcoin doesn't allow in config files."
echo ""

# Generate new password without problematic characters
NEW_BITCOIN_RPC_PASS=$(openssl rand -base64 32 | tr -d "=+/#" | cut -c1-25)

log_info "New RPC password generated: ${NEW_BITCOIN_RPC_PASS}"
echo ""

# Update setup-config.env
log_info "Updating setup-config.env..."
sed -i.backup "s/BITCOIN_RPC_PASS=.*/BITCOIN_RPC_PASS=\"${NEW_BITCOIN_RPC_PASS}\"/" setup-config.env

# Stop Bitcoin
log_info "Stopping Bitcoin Core..."
cd /opt/bitcoin
docker compose stop bitcoind

# Update docker-compose.yml
log_info "Updating docker-compose.yml..."
sed -i "s/rpcpassword=.*/rpcpassword=${NEW_BITCOIN_RPC_PASS}/" docker-compose.yml

# Update monitoring scripts
log_info "Updating monitoring scripts..."
if [[ -f "/opt/bitcoin/scripts/status.sh" ]]; then
    sed -i "s/KsVsyjn1Mfu9FA0H/${NEW_BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/status.sh
fi

if [[ -f "/opt/bitcoin/scripts/check-sync.sh" ]]; then
    sed -i "s/KsVsyjn1Mfu9FA0H/${NEW_BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/check-sync.sh
fi

if [[ -f "check-sync.sh" ]]; then
    sed -i "s/KsVsyjn1Mfu9FA0H/${NEW_BITCOIN_RPC_PASS}/g" check-sync.sh
fi

# Update complete-bitcoin-setup.sh
if [[ -f "complete-bitcoin-setup.sh" ]]; then
    sed -i "s/KsVsyjn1Mfu9FA0H/${NEW_BITCOIN_RPC_PASS}/g" complete-bitcoin-setup.sh
fi

# Start Bitcoin with new password
log_info "Starting Bitcoin Core with new password..."
docker compose up -d bitcoind

# Wait for Bitcoin to start
sleep 10

# Test the new password
log_info "Testing new configuration..."
if docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${NEW_BITCOIN_RPC_PASS} getblockchaininfo &>/dev/null; then
    log_success "Bitcoin Core is working with the new password!"
    echo ""
    echo "✅ Password successfully updated!"
    echo ""
    echo "New RPC credentials:"
    echo "Username: ${BITCOIN_RPC_USER}"
    echo "Password: ${NEW_BITCOIN_RPC_PASS}"
    echo ""
    echo "These have been saved in setup-config.env"
else
    log_error "Failed to connect with new password. Check docker logs bitcoind"
fi

# Show current sync status
echo ""
log_info "Current Bitcoin status:"
/opt/bitcoin/scripts/status.sh 2>/dev/null || echo "Run: cd /opt/bitcoin && ./scripts/status.sh"