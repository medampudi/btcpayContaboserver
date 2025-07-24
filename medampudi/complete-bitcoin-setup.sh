#!/bin/bash
set -eo pipefail

# Complete Bitcoin Setup - Run this after Bitcoin Core syncs
# This adds Fulcrum, Mempool, BTCPay, and other services

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Load configuration
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecurePassword}"
POSTGRES_PASS="${POSTGRES_PASS:-PostgresPass}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS:-MariaRootPass}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS:-MempoolPass}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.simbotix.com}"
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "127.0.0.1")

# Check if root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Check Bitcoin sync status
check_bitcoin_sync() {
    log_info "Checking Bitcoin sync status..."
    
    if ! docker ps | grep -q bitcoind; then
        log_error "Bitcoin Core is not running!"
        echo "Please start Bitcoin Core first:"
        echo "cd /opt/bitcoin && docker compose up -d bitcoind"
        exit 1
    fi
    
    # Get sync progress
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo 2>/dev/null || echo "{}")
    PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress // 0')
    
    # Convert to percentage
    PROGRESS_PCT=$(awk "BEGIN {printf \"%.1f\", $PROGRESS * 100}")
    
    log_info "Bitcoin sync progress: ${PROGRESS_PCT}%"
    
    if (( $(awk "BEGIN {print ($PROGRESS < 0.9)}") )); then
        log_warning "Bitcoin Core should be at least 90% synced before continuing"
        echo "Current progress: ${PROGRESS_PCT}%"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Create full docker-compose.yml
create_full_docker_compose() {
    log_info "Creating full docker-compose configuration..."
    
    # Backup existing
    cp /opt/bitcoin/docker-compose.yml /opt/bitcoin/docker-compose.yml.backup
    
    # Create full version
    cat > /opt/bitcoin/docker-compose.yml << EOF
version: '3.8'

networks:
  bitcoin:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

volumes:
  bitcoin_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/bitcoin/data/bitcoin
  fulcrum_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/bitcoin/data/fulcrum
  postgres_data:
    driver: local
  mempool_data:
    driver: local

services:
  # Bitcoin Core
  bitcoind:
    image: btcpayserver/bitcoin:26.0
    container_name: bitcoind
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.10
    volumes:
      - bitcoin_data:/data
    environment:
      BITCOIN_NETWORK: mainnet
      BITCOIN_EXTRA_ARGS: |
        rpcuser=${BITCOIN_RPC_USER}
        rpcpassword=${BITCOIN_RPC_PASS}
        rpcallowip=172.25.0.0/16
        rpcallowip=127.0.0.1
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
        listenonion=0
        zmqpubrawblock=tcp://0.0.0.0:28332
        zmqpubrawtx=tcp://0.0.0.0:28333
        whitelist=172.25.0.0/16
        maxconnections=125
        dbcache=4000
        maxmempool=2000
    ports:
      - "8333:8333"
      - "${TAILSCALE_IP}:8332:8332"

  # Fulcrum Electrum Server
  fulcrum:
    image: cculianu/fulcrum:latest
    container_name: fulcrum
    restart: unless-stopped
    depends_on:
      - bitcoind
    networks:
      bitcoin:
        ipv4_address: 172.25.0.20
    volumes:
      - fulcrum_data:/data
      - ./configs/fulcrum.conf:/etc/fulcrum.conf:ro
    ports:
      - "${TAILSCALE_IP}:50001:50001"
      - "${TAILSCALE_IP}:50002:50002"
    environment:
      - DATA_DIR=/data

  # PostgreSQL for BTCPay
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.30
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: btcpay
      POSTGRES_USER: btcpay
      POSTGRES_PASSWORD: ${POSTGRES_PASS}

  # MariaDB for Mempool
  mempool-db:
    image: mariadb:10.11
    container_name: mempool-db
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.40
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      MYSQL_DATABASE: mempool
      MYSQL_USER: mempool
      MYSQL_PASSWORD: ${MARIADB_MEMPOOL_PASS}
      MYSQL_ROOT_PASSWORD: ${MARIADB_ROOT_PASS}

  # Mempool API
  mempool-api:
    image: mempool/backend:latest
    container_name: mempool-api
    restart: unless-stopped
    depends_on:
      - bitcoind
      - fulcrum
      - mempool-db
    networks:
      bitcoin:
        ipv4_address: 172.25.0.41
    volumes:
      - ./configs/mempool-config.json:/backend/mempool-config.json:ro
      - mempool_data:/backend/cache
    environment:
      MEMPOOL_NETWORK: mainnet
      MEMPOOL_BACKEND: electrum
      ELECTRUM_HOST: fulcrum
      ELECTRUM_PORT: 50001
      ELECTRUM_TLS_ENABLED: "false"
      CORE_RPC_HOST: bitcoind
      CORE_RPC_PORT: 8332
      CORE_RPC_USERNAME: ${BITCOIN_RPC_USER}
      CORE_RPC_PASSWORD: ${BITCOIN_RPC_PASS}
      DATABASE_ENABLED: "true"
      DATABASE_HOST: mempool-db
      DATABASE_DATABASE: mempool
      DATABASE_USERNAME: mempool
      DATABASE_PASSWORD: ${MARIADB_MEMPOOL_PASS}

  # Mempool Frontend
  mempool-web:
    image: mempool/frontend:latest
    container_name: mempool-web
    restart: unless-stopped
    depends_on:
      - mempool-api
    networks:
      bitcoin:
        ipv4_address: 172.25.0.42
    ports:
      - "${TAILSCALE_IP}:8080:8080"
    environment:
      FRONTEND_HTTP_PORT: "8080"
      BACKEND_MAINNET_HTTP_HOST: mempool-api
      BACKEND_MAINNET_HTTP_PORT: 8999

  # BTC RPC Explorer
  btc-rpc-explorer:
    image: btcpayserver/btc-rpc-explorer:latest
    container_name: btc-explorer
    restart: unless-stopped
    depends_on:
      - bitcoind
      - fulcrum
    networks:
      bitcoin:
        ipv4_address: 172.25.0.50
    ports:
      - "${TAILSCALE_IP}:3002:3002"
    environment:
      BTCEXP_HOST: 0.0.0.0
      BTCEXP_PORT: 3002
      BTCEXP_BITCOIND_HOST: bitcoind
      BTCEXP_BITCOIND_PORT: 8332
      BTCEXP_BITCOIND_USER: ${BITCOIN_RPC_USER}
      BTCEXP_BITCOIND_PASS: ${BITCOIN_RPC_PASS}
      BTCEXP_ELECTRUM_SERVERS: tcp://fulcrum:50001
EOF
}

# Create Mempool config
create_mempool_config() {
    log_info "Creating Mempool configuration..."
    
    cat > /opt/bitcoin/configs/mempool-config.json << EOF
{
  "MEMPOOL": {
    "NETWORK": "mainnet",
    "BACKEND": "electrum",
    "HTTP_PORT": 8999,
    "API_URL_PREFIX": "/api/v1/",
    "POLL_RATE_MS": 2000
  },
  "CORE_RPC": {
    "HOST": "bitcoind",
    "PORT": 8332,
    "USERNAME": "${BITCOIN_RPC_USER}",
    "PASSWORD": "${BITCOIN_RPC_PASS}"
  },
  "ELECTRUM": {
    "HOST": "fulcrum",
    "PORT": 50001,
    "TLS_ENABLED": false
  },
  "DATABASE": {
    "ENABLED": true,
    "HOST": "mempool-db",
    "PORT": 3306,
    "DATABASE": "mempool",
    "USERNAME": "mempool",
    "PASSWORD": "${MARIADB_MEMPOOL_PASS}"
  }
}
EOF
}

# Start all services
start_all_services() {
    log_info "Starting all services..."
    
    cd /opt/bitcoin
    
    # Start databases first
    log_info "Starting databases..."
    docker compose up -d postgres mempool-db
    sleep 10
    
    # Start Fulcrum
    log_info "Starting Fulcrum Electrum server..."
    docker compose up -d fulcrum
    
    # Start Mempool
    log_info "Starting Mempool explorer..."
    docker compose up -d mempool-api mempool-web
    
    # Start BTC Explorer
    log_info "Starting BTC RPC Explorer..."
    docker compose up -d btc-rpc-explorer
    
    log_success "All services started!"
}

# Setup BTCPay Server
setup_btcpay() {
    log_info "Setting up BTCPay Server..."
    
    cd /opt/bitcoin
    
    # Clone BTCPay if not exists
    if [[ ! -d "btcpay/btcpayserver-docker" ]]; then
        mkdir -p btcpay
        cd btcpay
        git clone https://github.com/btcpayserver/btcpayserver-docker
    fi
    
    cd btcpay/btcpayserver-docker
    
    # Create environment
    cat > btcpay.env << EOF
export BTCPAY_HOST="${BTCPAY_DOMAIN}"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-add-thunderhub"
export BTCPAY_ENABLE_SSH=false
export BTCPAYGEN_EXCLUDE_FRAGMENTS="nginx-https"
export REVERSEPROXY_DEFAULT_HOST="${BTCPAY_DOMAIN}"
EOF

    source btcpay.env
    
    log_info "BTCPay Server prepared. Run './btcpay-setup.sh -i' to install"
}

# Create final status script
create_final_status_script() {
    log_info "Creating comprehensive status script..."
    
    cat > /opt/bitcoin/scripts/full-status.sh << 'EOF'
#!/bin/bash
clear
echo "=== Bitcoin Sovereignty Stack Status ==="
echo "========================================"
echo ""

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")

echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Tailscale IP: $TAILSCALE_IP"
echo "  Uptime: $(uptime -p)"
echo ""

echo "Service Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin|fulcrum|mempool|explorer|postgres"
echo ""

echo "Access URLs (via Tailscale):"
if [[ "$TAILSCALE_IP" != "Not connected" ]]; then
    echo "  Mempool Explorer: http://$TAILSCALE_IP:8080"
    echo "  BTC RPC Explorer: http://$TAILSCALE_IP:3002"
    echo "  Electrum Server: $TAILSCALE_IP:50001"
fi
echo ""

echo "Bitcoin Core Status:"
docker exec bitcoind bitcoin-cli getblockchaininfo 2>/dev/null | jq '{chain, blocks, headers, verificationprogress}' || echo "Not available"
EOF

    chmod +x /opt/bitcoin/scripts/full-status.sh
}

# Show completion
show_completion() {
    clear
    echo "=========================================="
    echo "✅ Bitcoin Stack Setup Complete!"
    echo "=========================================="
    echo ""
    echo "All services are now running:"
    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin|fulcrum|mempool|explorer"
    echo ""
    echo "Access your services via Tailscale:"
    echo "- Mempool Explorer: http://${TAILSCALE_IP}:8080"
    echo "- BTC RPC Explorer: http://${TAILSCALE_IP}:3002"
    echo "- Electrum Server: ${TAILSCALE_IP}:50001"
    echo ""
    echo "Configure your Bitcoin wallet:"
    echo "- Server: ${TAILSCALE_IP}"
    echo "- Port: 50001"
    echo "- No SSL/TLS needed within Tailscale"
    echo ""
    echo "Next steps:"
    echo "1. Setup BTCPay Server (optional):"
    echo "   cd /opt/bitcoin/btcpay/btcpayserver-docker"
    echo "   ./btcpay-setup.sh -i"
    echo ""
    echo "2. Monitor services:"
    echo "   /opt/bitcoin/scripts/full-status.sh"
    echo ""
}

# Main execution
main() {
    log_info "Starting Bitcoin stack completion..."
    
    check_bitcoin_sync
    create_mempool_config
    create_full_docker_compose
    start_all_services
    setup_btcpay
    create_final_status_script
    
    show_completion
}

# Run main
main "$@"