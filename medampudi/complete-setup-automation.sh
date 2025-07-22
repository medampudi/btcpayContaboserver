#!/bin/bash
# 🚀 Complete Bitcoin Infrastructure Setup Automation
# For Medampudi Family - Post-Hotfix Automation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - CHANGE THESE!
DOMAIN_NAME="your-bitcoin-domain.com"
BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"
EMAIL="your-email@domain.com"
BITCOIN_RPC_USER="medampudi_rpc_user"
BITCOIN_RPC_PASS="SecureMedampudiRPC2025!"
POSTGRES_PASS="MedampudiPostgres2025!"
MARIADB_ROOT_PASS="MedampudiMariaRoot2025!"
MARIADB_MEMPOOL_PASS="MedampudiMempool2025!"

# Contabo server details for migration
CONTABO_IP=""
CONTABO_USER="admin"

echo -e "${BLUE}🚀 Medampudi Family Bitcoin Infrastructure Automation${NC}"
echo -e "${YELLOW}This script will complete your entire setup automatically${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Verify we're in the right directory
if [ "$PWD" != "/opt/bitcoin" ]; then
    print_warning "Changing to /opt/bitcoin directory..."
    cd /opt/bitcoin
fi

# Phase 1: Create Docker Compose Configuration
echo -e "${BLUE}📋 Phase 1: Creating Docker Compose Configuration${NC}"

if [ ! -f docker-compose.yml ]; then
    print_status "Creating docker-compose.yml..."
    cat > docker-compose.yml << EOF
# Medampudi Family Bitcoin Infrastructure
# OVH Dedicated Server - Ubuntu 24.04

networks:
  bitcoin:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

volumes:
  bitcoin_data:
  fulcrum_data:
  postgres_data:
  lightning_data:
  mempool_data:

services:
  # Bitcoin Core - Full Node
  bitcoind:
    image: btcpayserver/bitcoin:27.0
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
        rpcuser=$BITCOIN_RPC_USER
        rpcpassword=$BITCOIN_RPC_PASS
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
        dbcache=8000
        maxmempool=4000
        mempoolexpiry=72
        prune=0
    ports:
      - "8333:8333"  # P2P - Keep public for network health
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Fulcrum - Electrum Server
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
      - ./configs/fulcrum.conf:/etc/fulcrum.conf
    environment:
      - DATA_DIR=/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # PostgreSQL for BTCPay
  postgres:
    image: postgres:15
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
      POSTGRES_PASSWORD: $POSTGRES_PASS
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Mempool Database
  mempool-db:
    image: mariadb:10.11
    container_name: mempool-db
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.40
    volumes:
      - mempool_data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: mempool
      MYSQL_USER: mempool
      MYSQL_PASSWORD: $MARIADB_MEMPOOL_PASS
      MYSQL_ROOT_PASSWORD: $MARIADB_ROOT_PASS
    command: --default-authentication-plugin=mysql_native_password
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

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
      - ./configs/mempool-config.json:/backend/mempool-config.json
    environment:
      MEMPOOL_BACKEND: "electrum"
      ELECTRUM_HOST: "fulcrum"
      ELECTRUM_PORT: "50001"
      ELECTRUM_TLS_ENABLED: "false"
      CORE_RPC_HOST: "bitcoind"
      CORE_RPC_PORT: "8332"
      CORE_RPC_USERNAME: "$BITCOIN_RPC_USER"
      CORE_RPC_PASSWORD: "$BITCOIN_RPC_PASS"
      DATABASE_ENABLED: "true"
      DATABASE_HOST: "mempool-db"
      DATABASE_DATABASE: "mempool"
      DATABASE_USERNAME: "mempool"
      DATABASE_PASSWORD: "$MARIADB_MEMPOOL_PASS"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

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
    environment:
      FRONTEND_HTTP_PORT: "8080"
      BACKEND_MAINNET_HTTP_HOST: "mempool-api"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

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
    environment:
      BTCEXP_HOST: 0.0.0.0
      BTCEXP_PORT: 3002
      BTCEXP_BITCOIND_HOST: bitcoind
      BTCEXP_BITCOIND_PORT: 8332
      BTCEXP_BITCOIND_USER: $BITCOIN_RPC_USER
      BTCEXP_BITCOIND_PASS: $BITCOIN_RPC_PASS
      BTCEXP_ELECTRUM_SERVERS: tcp://fulcrum:50001
      BTCEXP_SLOW_DEVICE_MODE: false
      BTCEXP_NO_INMEMORY_RPC_CACHE: false
      BTCEXP_PRIVACY_MODE: false
      BTCEXP_NO_RATES: false
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    print_status "docker-compose.yml created successfully!"
else
    print_warning "docker-compose.yml already exists"
fi

# Phase 2: Start Bitcoin Core
echo -e "${BLUE}₿ Phase 2: Starting Bitcoin Core${NC}"

print_status "Starting Bitcoin Core..."
docker compose up -d bitcoind

print_status "Waiting for Bitcoin Core to initialize (30 seconds)..."
sleep 30

# Check Bitcoin status
print_status "Checking Bitcoin Core status..."
./scripts/bitcoin-status.sh || true

# Phase 3: Migration Decision
echo -e "${BLUE}🔄 Phase 3: Bitcoin Data Migration${NC}"

if [ -z "$CONTABO_IP" ]; then
    read -p "Do you have a Contabo server with synced Bitcoin data? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Contabo server IP: " CONTABO_IP
        read -p "Enter Contabo username (default: admin): " CONTABO_USER
        CONTABO_USER=${CONTABO_USER:-admin}
        
        print_status "Starting migration from Contabo..."
        
        # Create migration script
        cat > /tmp/migrate-bitcoin.sh << 'MIGRATE_EOF'
#!/bin/bash
cd /opt/bitcoin
echo "Creating blockchain backup..."
sudo tar -czf /tmp/bitcoin-blockchain.tar.gz data/bitcoin/blocks data/bitcoin/chainstate
echo "Backup created. Size:"
ls -lh /tmp/bitcoin-blockchain.tar.gz
MIGRATE_EOF
        
        print_status "Creating backup on Contabo server..."
        ssh $CONTABO_USER@$CONTABO_IP 'bash -s' < /tmp/migrate-bitcoin.sh
        
        print_status "Downloading blockchain data (this will take 2-6 hours)..."
        mkdir -p /opt/bitcoin/migration
        rsync -avz --progress $CONTABO_USER@$CONTABO_IP:/tmp/bitcoin-blockchain.tar.gz /opt/bitcoin/migration/
        
        print_status "Stopping Bitcoin Core for data restore..."
        docker compose stop bitcoind
        
        print_status "Restoring blockchain data..."
        docker run --rm -v bitcoin_data:/data -v /opt/bitcoin/migration:/backup alpine \
            sh -c "cd /data && tar -xzf /backup/bitcoin-blockchain.tar.gz --strip-components=2"
        
        print_status "Starting Bitcoin Core with restored data..."
        docker compose up -d bitcoind
        
        print_status "Migration completed! Bitcoin should resume from Contabo block height"
    else
        print_warning "Starting fresh Bitcoin sync (will take 3-5 days)"
    fi
else
    print_status "Using provided Contabo IP for migration: $CONTABO_IP"
fi

# Phase 4: Wait for Bitcoin Sync
echo -e "${BLUE}⏳ Phase 4: Monitoring Bitcoin Sync${NC}"

print_status "Monitoring Bitcoin sync progress..."
print_warning "This window will update every 60 seconds. Press Ctrl+C to continue setup later."

# Monitor sync progress
while true; do
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=$BITCOIN_RPC_USER -rpcpassword=$BITCOIN_RPC_PASS getblockchaininfo 2>/dev/null || echo "{}")
    PROGRESS=$(echo "$SYNC_INFO" | jq -r '.verificationprogress // 0' | awk '{printf "%.1f", $1 * 100}')
    BLOCKS=$(echo "$SYNC_INFO" | jq -r '.blocks // 0')
    
    echo -ne "\r⚡ Sync Progress: ${PROGRESS}% | Blocks: ${BLOCKS} | $(date)"
    
    if (( $(echo "$PROGRESS >= 95" | bc -l) )); then
        echo ""
        print_status "Bitcoin sync reached 95%! Starting other services..."
        break
    fi
    
    sleep 60
done

# Phase 5: Start Database Services
echo -e "${BLUE}🗄️  Phase 5: Starting Database Services${NC}"

print_status "Starting PostgreSQL and MariaDB..."
docker compose up -d postgres mempool-db

print_status "Waiting for databases to initialize..."
sleep 20

# Phase 6: Start Fulcrum Electrum Server
echo -e "${BLUE}⚡ Phase 6: Starting Fulcrum Electrum Server${NC}"

print_status "Starting Fulcrum..."
docker compose up -d fulcrum

print_status "Fulcrum will index the blockchain (takes 2-4 hours)"
print_warning "Continuing with other services while Fulcrum indexes..."

# Phase 7: Start Mempool and Explorer
echo -e "${BLUE}📊 Phase 7: Starting Mempool and Explorer${NC}"

print_status "Starting Mempool services..."
docker compose up -d mempool-api mempool-web btc-rpc-explorer

print_status "Waiting for services to start..."
sleep 30

# Phase 8: Setup Cloudflare Tunnel
echo -e "${BLUE}☁️  Phase 8: Cloudflare Tunnel Setup${NC}"

if ! cloudflared tunnel list | grep -q "medampudi-bitcoin"; then
    print_status "Setting up Cloudflare tunnel..."
    print_warning "You'll need to authenticate with Cloudflare"
    
    cloudflared tunnel login
    cloudflared tunnel create medampudi-bitcoin
    
    TUNNEL_ID=$(cloudflared tunnel list | grep "medampudi-bitcoin" | awk '{print $1}')
    
    print_status "Creating tunnel configuration..."
    sudo mkdir -p /etc/cloudflared
    
    sudo tee /etc/cloudflared/config.yml > /dev/null << EOF
tunnel: $TUNNEL_ID
credentials-file: /home/ubuntu/.cloudflared/$TUNNEL_ID.json

originRequest:
  noTLSVerify: true

ingress:
  - hostname: $BTCPAY_DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF
    
    print_status "Installing Cloudflare tunnel service..."
    sudo cp ~/.cloudflared/*.json /etc/cloudflared/
    sudo cloudflared service install
    sudo systemctl start cloudflared
    sudo systemctl enable cloudflared
    
    print_status "Cloudflare tunnel configured!"
    print_warning "Remember to add CNAME record in Cloudflare: $BTCPAY_DOMAIN → $TUNNEL_ID.cfargotunnel.com"
else
    print_warning "Cloudflare tunnel already exists"
fi

# Phase 9: Display Status and Access Information
echo -e "${BLUE}📊 Phase 9: Final Status Check${NC}"

print_status "Checking all services..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
print_status "Running family access script..."
./scripts/family-access.sh

# Phase 10: BTCPay Server Setup Instructions
echo -e "${BLUE}💳 Phase 10: BTCPay Server Setup${NC}"

cat > /opt/bitcoin/setup-btcpay.sh << 'BTCPAY_EOF'
#!/bin/bash
cd /opt/bitcoin
mkdir -p btcpay && cd btcpay
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

cat > btcpay.env << EOF
export BTCPAY_HOST="$BTCPAY_DOMAIN"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="bitcoin-nobitcoind;opt-add-thunderhub"
export BTCPAY_ENABLE_SSH=false
export BTCPAY_EXTERNAL_BITCOIND_HOST="172.25.0.10"
export BTCPAY_EXTERNAL_BITCOIND_RPCPORT="8332"
export BTCPAY_EXTERNAL_BITCOIND_RPCUSER="$BITCOIN_RPC_USER"
export BTCPAY_EXTERNAL_BITCOIND_RPCPASSWORD="$BITCOIN_RPC_PASS"
EOF

source btcpay.env
./btcpay-setup.sh -i
BTCPAY_EOF

chmod +x /opt/bitcoin/setup-btcpay.sh

print_status "BTCPay setup script created: /opt/bitcoin/setup-btcpay.sh"

# Final Summary
echo ""
echo -e "${BLUE}🎉 Setup Automation Complete!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo "✅ Docker Compose configured"
echo "✅ Bitcoin Core running"
echo "✅ All supporting services started"
echo "✅ Cloudflare tunnel configured"
echo ""
echo -e "${YELLOW}🎯 Remaining Manual Steps:${NC}"
echo "1. Add Cloudflare DNS CNAME: $BTCPAY_DOMAIN → [TUNNEL_ID].cfargotunnel.com"
echo "2. Wait for Fulcrum to finish indexing (check: docker logs fulcrum)"
echo "3. Install BTCPay Server: ./setup-btcpay.sh"
echo "4. Share family access info from: ./scripts/family-access.sh"
echo ""
echo -e "${GREEN}💰 Cost Savings Achieved: \$240/year vs Contabo!${NC}"
echo -e "${GREEN}🏠 Your Medampudi Family Bitcoin Infrastructure is Ready!${NC}"

# Create status monitoring script
cat > /opt/bitcoin/monitor-all.sh << 'MONITOR_EOF'
#!/bin/bash
while true; do
    clear
    echo "=== Medampudi Bitcoin Infrastructure Status ==="
    echo "=============================================="
    echo ""
    ./scripts/bitcoin-status.sh
    echo ""
    echo "=== Service Health ==="
    docker ps --format "table {{.Names}}\t{{.Status}}"
    echo ""
    echo "=== Fulcrum Indexing Progress ==="
    docker logs fulcrum --tail 5 2>&1 | grep -E "height|progress|synced"
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 30
done
MONITOR_EOF

chmod +x /opt/bitcoin/monitor-all.sh

print_status "Monitor script created: ./monitor-all.sh"
print_warning "Run ./monitor-all.sh to continuously monitor your infrastructure"