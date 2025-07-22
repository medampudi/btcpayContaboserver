#!/bin/bash
# Hotfix to continue setup from where it failed

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Continuing Medampudi Family Bitcoin Setup${NC}"
echo -e "${YELLOW}Picking up from Phase 7...${NC}"

# Load your configuration
DOMAIN_NAME="your-bitcoin-domain.com"
BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"
EMAIL="your-email@domain.com"
BITCOIN_RPC_USER="medampudi_rpc_user"
BITCOIN_RPC_PASS="SecureMedampudiRPC2025!"
POSTGRES_PASS="MedampudiPostgres2025!"
MARIADB_ROOT_PASS="MedampudiMariaRoot2025!"
MARIADB_MEMPOOL_PASS="MedampudiMempool2025!"

# Phase 7: Bitcoin Infrastructure Setup
echo -e "${BLUE}₿ Phase 7: Bitcoin Infrastructure Preparation${NC}"

echo "Creating Bitcoin directory structure..."
sudo mkdir -p /opt/bitcoin/{data,configs,backups,logs,scripts}
sudo chown -R $USER:$USER /opt/bitcoin
cd /opt/bitcoin

echo "Creating configuration files..."

# Create Fulcrum config
mkdir -p configs
cat > configs/fulcrum.conf << EOF
datadir = /data
bitcoind = bitcoind:8332
rpcuser = $BITCOIN_RPC_USER
rpcpassword = $BITCOIN_RPC_PASS

tcp = 0.0.0.0:50001
ssl = 0.0.0.0:50002

cert = /data/fulcrum.crt
key = /data/fulcrum.key
peering = false

fast-sync = 1
db_max_open_files = 1000
db_mem = 16000.0
bitcoind_timeout = 300
bitcoind_clients = 8
worker_threads = 0
EOF

# Create Mempool config
cat > configs/mempool-config.json << EOF
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
    "USERNAME": "$BITCOIN_RPC_USER",
    "PASSWORD": "$BITCOIN_RPC_PASS"
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
    "PASSWORD": "$MARIADB_MEMPOOL_PASS"
  }
}
EOF

# Create the docker-compose.yml (already in original script)
echo "Docker compose file should already exist..."

# Create management scripts
echo "Creating management scripts..."

# Bitcoin status script
cat > scripts/bitcoin-status.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "₿ === Medampudi Family Bitcoin Node Status ==="
echo "=============================================="

# Get variables from environment
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-medampudi_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecureMedampudiRPC2025!}"

if docker ps | grep -q bitcoind; then
    echo "✅ Bitcoin Core: Running"
    
    BLOCKCHAIN_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=$BITCOIN_RPC_USER -rpcpassword=$BITCOIN_RPC_PASS getblockchaininfo 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        BLOCKS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks')
        HEADERS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.headers')
        PROGRESS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.verificationprogress * 100' | cut -d. -f1)
        SIZE_GB=$(echo "$BLOCKCHAIN_INFO" | jq -r '.size_on_disk / 1000000000' | cut -d. -f1)
        
        echo "📊 Current Block: $BLOCKS"
        echo "📊 Headers: $HEADERS"
        echo "📊 Sync Progress: $PROGRESS%"
        echo "📊 Blockchain Size: ${SIZE_GB}GB"
        
        PEERS=$(docker exec bitcoind bitcoin-cli -rpcuser=$BITCOIN_RPC_USER -rpcpassword=$BITCOIN_RPC_PASS getconnectioncount 2>/dev/null)
        echo "🌐 Connected Peers: $PEERS"
    else
        echo "❌ Cannot connect to Bitcoin RPC"
    fi
else
    echo "❌ Bitcoin Core: Not Running"
fi

echo ""
echo "🐳 Docker Services Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "bitcoind|fulcrum|mempool|btc-explorer|postgres"

echo ""
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
echo "🔗 Tailscale IP: $TAILSCALE_IP"
SCRIPT_EOF

chmod +x scripts/bitcoin-status.sh

# Family access script
cat > scripts/family-access.sh << 'SCRIPT_EOF'
#!/bin/bash
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")

echo "🏠 === Medampudi Family Bitcoin Services ==="
echo "============================================"
echo ""
echo "👨‍💼 For Parents (Rajesh & Apoorva):"
echo "Bitcoin Explorer:     http://$TAILSCALE_IP:3002"
echo "Mempool Explorer:     http://$TAILSCALE_IP:8080"
echo "Server SSH:           ssh $(whoami)@$TAILSCALE_IP"
echo ""
echo "👨‍👩‍👧‍👦 For All Family Members:"
echo "BTCPay Server:        https://pay.your-domain.com"
echo "Electrum Server:      $TAILSCALE_IP:50001"
echo "Lightning Node:       $TAILSCALE_IP:9735"
echo ""
echo "📱 Mobile Wallet Setup:"
echo "Server: $TAILSCALE_IP"
echo "Port: 50001 (TCP) or 50002 (SSL)"
SCRIPT_EOF

chmod +x scripts/family-access.sh

# Migration script
cat > scripts/migrate-from-contabo.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "🔄 Migrating Bitcoin data from Contabo server..."
echo "This script will help you migrate your synced blockchain"

read -p "Enter Contabo server IP: " CONTABO_IP
read -p "Enter Contabo username (default: admin): " CONTABO_USER
CONTABO_USER=${CONTABO_USER:-admin}

echo "Creating migration directory..."
mkdir -p /opt/bitcoin/migration

echo "Please run these commands on your Contabo server:"
echo "---------------------------------------------"
echo "ssh $CONTABO_USER@$CONTABO_IP"
echo "cd /opt/bitcoin"
echo "sudo tar -czf /tmp/bitcoin-blockchain.tar.gz data/bitcoin/blocks data/bitcoin/chainstate"
echo "---------------------------------------------"
echo ""
read -p "Press Enter after running the above commands on Contabo..."

echo "Downloading blockchain data from Contabo..."
rsync -avz --progress $CONTABO_USER@$CONTABO_IP:/tmp/bitcoin-blockchain.tar.gz /opt/bitcoin/migration/

echo "Restoring blockchain data..."
cd /opt/bitcoin
docker compose stop bitcoind || true
sudo docker run --rm -v bitcoin_data:/data -v /opt/bitcoin/migration:/backup alpine sh -c "cd /data && tar -xzf /backup/bitcoin-blockchain.tar.gz --strip-components=2"

echo "Starting Bitcoin with restored data..."
docker compose up -d bitcoind

echo "✅ Migration completed! Check status with: ./scripts/bitcoin-status.sh"
SCRIPT_EOF

chmod +x scripts/migrate-from-contabo.sh

echo -e "${GREEN}✅ Management scripts created successfully!${NC}"

# Create systemd service
echo "Creating system service..."
sudo tee /etc/systemd/system/bitcoin-family-status.service > /dev/null << EOF
[Unit]
Description=Medampudi Family Bitcoin Status Service
After=docker.service

[Service]
Type=oneshot
User=$USER
ExecStart=/opt/bitcoin/scripts/bitcoin-status.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bitcoin-family-status.service

echo ""
echo -e "${BLUE}🎉 Setup Continuation Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. 🔐 Edit this hotfix script with your actual configuration values"
echo "2. 🚀 Start Docker services: cd /opt/bitcoin && docker compose up -d"
echo "3. 📊 Check status: ./scripts/bitcoin-status.sh"
echo "4. 🔄 Migrate from Contabo: ./scripts/migrate-from-contabo.sh"
echo "5. ☁️  Setup Cloudflare tunnel manually"
echo ""
echo -e "${GREEN}Your Bitcoin infrastructure is ready!${NC}"