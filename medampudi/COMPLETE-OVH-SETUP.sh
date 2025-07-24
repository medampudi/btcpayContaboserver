#!/bin/bash
# 🚀 Complete OVH Bitcoin Stack Setup - Fresh Installation
# For Medampudi Family - Ubuntu 24.04 Server
# This script sets up everything from scratch without Contabo dependency

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# CONFIGURATION - CHANGE THESE VALUES
# ============================================
DOMAIN_NAME="simbotix.com"              # Your main domain
BTCPAY_DOMAIN="pay.simbotix.com"        # BTCPay subdomain
EMAIL="medampudi@gmail.com"                      # Your email
FAMILY_NAME="Medampudi-Family"                     # Family identifier

# Passwords - CHANGE ALL OF THESE TO STRONG PASSWORDS
BITCOIN_RPC_USER="medampudi_rpc_user"
BITCOIN_RPC_PASS="SecureMedampudiRPC2025!"
POSTGRES_PASS="MedampudiPostgres2025!"
MARIADB_ROOT_PASS="MedampudiMariaRoot2025!"
MARIADB_MEMPOOL_PASS="MedampudiMempool2025!"

# Server Configuration
TIMEZONE="Asia/Kolkata"
SWAP_SIZE="8G"

# Get these from respective services
TAILSCALE_AUTHKEY="tskey-auth-kJb6AMjABs11CNTRL-486hP8fFxdK3BxPbfgaYdKG4xUeZTJa4"  # Get from https://login.tailscale.com/admin/settings/keys
CLOUDFLARE_API_TOKEN="e3Gb-_waN9wUZs9RkZHATDcsVCQVxUEc2kwxNPkh"  # Get from Cloudflare dashboard
CLOUDFLARE_ZONE_ID=""    # Your domain's zone ID in Cloudflare

# ============================================
# DO NOT MODIFY BELOW THIS LINE
# ============================================

echo -e "${BLUE}🚀 Starting Complete OVH Bitcoin Stack Setup${NC}"
echo -e "${YELLOW}📊 Fresh Installation for Medampudi Family${NC}"
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

# Verify configuration
if [ "$DOMAIN_NAME" = "your-bitcoin-domain.com" ]; then
    print_error "Please edit this script and set your configuration values first!"
    print_error "Edit the CONFIGURATION section at the top of this file"
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Run as ubuntu user with sudo access."
   exit 1
fi

# Phase 1: System Updates and Basic Setup
echo -e "${BLUE}🔧 Phase 1: System Updates and Basic Configuration${NC}"

print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

print_status "Installing essential packages..."
sudo apt install -y \
    curl wget git vim htop ncdu tree \
    ufw fail2ban net-tools \
    software-properties-common apt-transport-https \
    jq unzip zip \
    build-essential \
    python3 python3-pip \
    ca-certificates gnupg lsb-release

print_status "Setting timezone..."
sudo timedatectl set-timezone $TIMEZONE

print_status "Configuring swap file..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l $SWAP_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_status "Swap file created: $SWAP_SIZE"
else
    print_warning "Swap file already exists"
fi

# Phase 2: Install Docker
echo -e "${BLUE}🐳 Phase 2: Docker Installation${NC}"

if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "Docker installed"
else
    print_warning "Docker already installed"
fi

if ! command -v docker compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    sudo apt install -y docker-compose-v2
    print_status "Docker Compose installed"
fi

# Phase 3: Install Tailscale
echo -e "${BLUE}🔗 Phase 3: Tailscale VPN Setup${NC}"

if ! command -v tailscale &> /dev/null; then
    print_status "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    print_status "Tailscale installed"
fi

if [ ! -z "$TAILSCALE_AUTHKEY" ]; then
    print_status "Connecting to Tailscale..."
    sudo tailscale up --authkey=$TAILSCALE_AUTHKEY --hostname="medampudi-bitcoin-ovh" --accept-routes
    TAILSCALE_IP=$(tailscale ip -4)
    print_status "Tailscale connected. IP: $TAILSCALE_IP"
else
    print_warning "Tailscale auth key not provided. Run manually later: sudo tailscale up"
fi

# Phase 4: Install Cloudflared
echo -e "${BLUE}☁️  Phase 4: Cloudflare Tunnel Setup${NC}"

if ! command -v cloudflared &> /dev/null; then
    print_status "Installing Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    print_status "Cloudflared installed"
fi

# Phase 5: Firewall Configuration
echo -e "${BLUE}🛡️  Phase 5: Firewall Configuration${NC}"

print_status "Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 8333/tcp comment 'Bitcoin P2P'
sudo ufw allow 9735/tcp comment 'Lightning Network'
sudo ufw allow in on tailscale0
sudo ufw --force enable
print_status "Firewall configured"

# Phase 6: Create Bitcoin Infrastructure
echo -e "${BLUE}₿ Phase 6: Bitcoin Infrastructure Setup${NC}"

print_status "Creating directory structure..."
sudo mkdir -p /opt/bitcoin/{data,configs,backups,logs,scripts}
sudo chown -R $USER:$USER /opt/bitcoin
cd /opt/bitcoin

# Create all configuration files
print_status "Creating configuration files..."

mkdir -p configs

# Bitcoin configuration
cat > configs/bitcoin.conf << EOF
# Bitcoin Core Configuration
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
EOF

# Fulcrum configuration
cat > configs/fulcrum.conf << EOF
# Fulcrum Electrum Server Configuration
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

# Mempool configuration
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

# BTCPay environment file
cat > btcpay.env << EOF
BTCPAY_HOST=$BTCPAY_DOMAIN
BTCPAY_ROOTPATH=/
BTCPAY_PROTOCOL=https
BTCPAY_PORT=443
BTCPAY_SSHKEYFILE=/datadir/host_key
BTCPAY_SSHTRUSTEDFINGERPRINTS=
BTCPAY_DEBUGLOG=btcpay.log
BTCPAY_DOCKERDEPLOYMENT=true
BTCPAY_UPDATEURL=https://raw.githubusercontent.com/btcpayserver/btcpay-docker/master/docker-compose.btcpay.yml
BTCPAY_SSHAUTHORIZEDKEYS=
BTCPAY_TORRCFILE=/usr/local/etc/tor/torrc-2
BTCPAY_SOCKSENDPOINT=tor:9050
POSTGRES_PASSWORD=$POSTGRES_PASS
BITCOIN_NETWORK=mainnet
LIGHTNING_ALIAS=MedampudiFamily
BTCPAY_ENABLE_SSH=false
EOF

# Phase 7: Docker Compose Setup
print_status "Creating Docker Compose configuration..."

cat > docker-compose.yml << 'EOF'
# Medampudi Family Bitcoin Infrastructure
# Complete Stack on OVH Server

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
  btcpay_data:
  btcpay_postgres_data:

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
      - ./configs/bitcoin.conf:/data/bitcoin.conf
    ports:
      - "8333:8333"  # P2P
    environment:
      BITCOIN_NETWORK: mainnet
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "5"

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
        max-size: "50m"
        max-file: "5"

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
      POSTGRES_PASSWORD: ${POSTGRES_PASS}

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
      MYSQL_PASSWORD: ${MARIADB_MEMPOOL_PASS}
      MYSQL_ROOT_PASSWORD: ${MARIADB_ROOT_PASS}
    command: --default-authentication-plugin=mysql_native_password

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
      CORE_RPC_USERNAME: "${BITCOIN_RPC_USER}"
      CORE_RPC_PASSWORD: "${BITCOIN_RPC_PASS}"
      DATABASE_ENABLED: "true"
      DATABASE_HOST: "mempool-db"
      DATABASE_DATABASE: "mempool"
      DATABASE_USERNAME: "mempool"
      DATABASE_PASSWORD: "${MARIADB_MEMPOOL_PASS}"

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
    ports:
      - "127.0.0.1:8080:8080"  # Only on localhost

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
      BTCEXP_BITCOIND_USER: ${BITCOIN_RPC_USER}
      BTCEXP_BITCOIND_PASS: ${BITCOIN_RPC_PASS}
      BTCEXP_ELECTRUM_SERVERS: tcp://fulcrum:50001
      BTCEXP_SLOW_DEVICE_MODE: false
      BTCEXP_NO_INMEMORY_RPC_CACHE: false
      BTCEXP_PRIVACY_MODE: false
      BTCEXP_NO_RATES: false
    ports:
      - "127.0.0.1:3002:3002"  # Only on localhost

  # BTCPay Server
  btcpayserver:
    image: btcpayserver/btcpayserver:1.13.1
    container_name: btcpayserver
    restart: unless-stopped
    depends_on:
      - postgres
    networks:
      bitcoin:
        ipv4_address: 172.25.0.60
    volumes:
      - btcpay_data:/datadir
      - ./btcpay.env:/.env
    environment:
      BTCPAY_HOST: ${BTCPAY_DOMAIN}
      BTCPAY_ROOTPATH: /
      BTCPAY_PROTOCOL: https
      BTCPAY_PORT: 443
      BTCPAY_CHAINS: btc
      BTCPAY_BTCEXPLORERURL: http://btc-explorer:3002
      BTCPAY_BTCEXPLORERCOOKIEFILE: /datadir/cookie
      BTCPAY_POSTGRES: User ID=btcpay;Password=${POSTGRES_PASS};Host=postgres;Port=5432;Database=btcpay;
      BTCPAY_DEBUGLOG: btcpay.log
      BTCPAY_NETWORK: mainnet
      BTCPAY_BIND: 0.0.0.0:49392
      BTCPAY_EXTERNALURL: https://${BTCPAY_DOMAIN}
      BTCPAY_SOCKSENDPOINT: tor:9050
    ports:
      - "127.0.0.1:49392:49392"  # Only on localhost
EOF

# Add environment variables substitution
cat >> docker-compose.yml << EOF

  # Lightning Network (c-lightning)
  lightningd:
    image: btcpayserver/lightning:v24.08.2
    container_name: lightningd
    restart: unless-stopped
    depends_on:
      - bitcoind
    networks:
      bitcoin:
        ipv4_address: 172.25.0.70
    volumes:
      - lightning_data:/root/.lightning
    environment:
      LIGHTNINGD_NETWORK: mainnet
      LIGHTNINGD_CHAIN: btc
      LIGHTNINGD_OPT: |
        bitcoin-datadir=/etc/bitcoin
        bitcoin-rpcconnect=bitcoind
        bitcoin-rpcport=8332
        bitcoin-rpcuser=$BITCOIN_RPC_USER
        bitcoin-rpcpassword=$BITCOIN_RPC_PASS
        alias=$FAMILY_NAME-Lightning
        log-level=info
        wallet=sqlite3:///root/.lightning/lightningd.sqlite3
    ports:
      - "9735:9735"  # Lightning P2P

  # Thunderhub Lightning Management
  thunderhub:
    image: apotdevin/thunderhub:v0.13.31
    container_name: thunderhub
    restart: unless-stopped
    depends_on:
      - lightningd
    networks:
      bitcoin:
        ipv4_address: 172.25.0.71
    volumes:
      - ./configs/thunderhub.yml:/app/config.yml
    environment:
      ACCOUNT_CONFIG_PATH: /app/config.yml
    ports:
      - "127.0.0.1:3000:3000"  # Only on localhost
EOF

# Create Thunderhub config
cat > configs/thunderhub.yml << EOF
masterPassword: 'thunderhub'
accounts:
  - name: '$FAMILY_NAME Lightning'
    serverUrl: 'lightningd:9735'
    lndDir: '/root/.lightning'
    network: 'mainnet'
    type: 'clightning'
EOF

# Phase 8: Create Management Scripts
print_status "Creating management scripts..."

mkdir -p scripts

# Status script
cat > scripts/status.sh << 'EOF'
#!/bin/bash
# Bitcoin Node Status Check

echo "₿ === Bitcoin Stack Status ==="
echo "=============================="
echo ""

# Check Docker services
echo "🐳 Docker Services:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|bitcoind|fulcrum|mempool|btc-explorer|btcpay|lightning|thunderhub|postgres"

echo ""
echo "📊 Bitcoin Sync Status:"
if docker ps | grep -q bitcoind; then
    docker exec bitcoind bitcoin-cli -conf=/data/bitcoin.conf getblockchaininfo | jq '{blocks, headers, verificationprogress, size_on_disk}'
else
    echo "❌ Bitcoin Core not running"
fi

echo ""
echo "💾 Disk Usage:"
df -h /opt/bitcoin

echo ""
echo "🔗 Network Status:"
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
echo "Tailscale IP: $TAILSCALE_IP"

if [ "$TAILSCALE_IP" != "Not connected" ]; then
    echo ""
    echo "📱 Access URLs:"
    echo "Mempool:      http://$TAILSCALE_IP:8080"
    echo "Explorer:     http://$TAILSCALE_IP:3002"
    echo "Thunderhub:   http://$TAILSCALE_IP:3000"
    echo "Electrum:     $TAILSCALE_IP:50001"
fi
EOF

chmod +x scripts/status.sh

# Quick access script
cat > scripts/access-info.sh << 'EOF'
#!/bin/bash
# Family Access Information

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")

echo "🏠 === Family Bitcoin Services ==="
echo "================================="
echo ""
echo "📱 Mobile Wallet Setup:"
echo "Electrum Server: $TAILSCALE_IP:50001"
echo ""
echo "🌐 Web Services (via Tailscale):"
echo "Mempool Explorer:  http://$TAILSCALE_IP:8080"
echo "Bitcoin Explorer:  http://$TAILSCALE_IP:3002"
echo "Lightning Manager: http://$TAILSCALE_IP:3000"
echo ""
echo "💳 BTCPay Server (Public):"
echo "https://$BTCPAY_DOMAIN"
echo ""
echo "⚡ Lightning Node:"
echo "Node ID: $(docker exec lightningd lightning-cli getinfo 2>/dev/null | jq -r .id || echo 'Not ready')"
EOF

chmod +x scripts/access-info.sh

# Backup script
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup critical data

BACKUP_DIR="/opt/bitcoin/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔒 Backing up critical data..."

# Backup configurations
cp -r /opt/bitcoin/configs "$BACKUP_DIR/"

# Backup wallet if exists
if docker exec bitcoind test -d /data/wallet; then
    docker exec bitcoind tar -czf - -C /data wallet | cat > "$BACKUP_DIR/bitcoin-wallet.tar.gz"
    echo "✅ Bitcoin wallet backed up"
fi

# Backup Lightning
if docker exec lightningd test -d /root/.lightning; then
    docker exec lightningd tar -czf - -C /root/.lightning hsm_secret | cat > "$BACKUP_DIR/lightning-hsm.tar.gz"
    echo "✅ Lightning keys backed up"
fi

# Backup BTCPay
docker exec postgres pg_dump -U btcpay btcpay | gzip > "$BACKUP_DIR/btcpay-db.sql.gz"
echo "✅ BTCPay database backed up"

echo ""
echo "✅ Backup completed: $BACKUP_DIR"
echo "⚠️  Store these backups securely offline!"
EOF

chmod +x scripts/backup.sh

# Phase 9: Cloudflare Tunnel Configuration
if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    print_status "Setting up Cloudflare Tunnel..."
    
    # Create tunnel configuration
    cat > configs/cloudflare-tunnel.yml << EOF
tunnel: medampudi-bitcoin
credentials-file: /opt/bitcoin/configs/tunnel-credentials.json

ingress:
  - hostname: $BTCPAY_DOMAIN
    service: http://localhost:49392
  - service: http_status:404
EOF
    
    print_status "Cloudflare tunnel configuration created"
else
    print_warning "Cloudflare API token not provided. Configure tunnel manually later."
fi

# Phase 10: Start Services
echo -e "${BLUE}🚀 Phase 10: Starting Services${NC}"

print_status "Starting Bitcoin stack..."
cd /opt/bitcoin

# Export environment variables for docker-compose
export BITCOIN_RPC_USER
export BITCOIN_RPC_PASS
export POSTGRES_PASS
export MARIADB_ROOT_PASS
export MARIADB_MEMPOOL_PASS
export BTCPAY_DOMAIN
export FAMILY_NAME

# Start services
docker compose up -d

print_status "Waiting for services to initialize..."
sleep 30

# Phase 11: Post-Setup Tasks
echo -e "${BLUE}🔧 Phase 11: Post-Setup Configuration${NC}"

# Generate SSL certificate for Fulcrum
print_status "Generating SSL certificate for Fulcrum..."
docker exec fulcrum sh -c "cd /data && openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout fulcrum.key -out fulcrum.crt -subj '/CN=fulcrum'"

# Create cron jobs
print_status "Setting up automatic backups..."
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/bitcoin/scripts/backup.sh") | crontab -

# Final Summary
echo ""
echo -e "${GREEN}🎉 ========================================${NC}"
echo -e "${GREEN}🎉 OVH Bitcoin Stack Setup Complete!${NC}"
echo -e "${GREEN}🎉 ========================================${NC}"
echo ""

print_status "All services are starting up..."
echo ""
echo -e "${YELLOW}📋 What's Next:${NC}"
echo ""
echo "1. ⏳ Wait for Bitcoin to sync (2-3 days for full sync)"
echo "   Check progress: docker exec bitcoind bitcoin-cli -conf=/data/bitcoin.conf getblockchaininfo"
echo ""
echo "2. 🔗 Connect Tailscale if not done:"
echo "   sudo tailscale up"
echo ""
echo "3. ☁️  Setup Cloudflare Tunnel:"
echo "   cloudflared tunnel login"
echo "   cloudflared tunnel create medampudi-bitcoin"
echo "   cloudflared tunnel route dns medampudi-bitcoin $BTCPAY_DOMAIN"
echo ""
echo "4. 📊 Monitor status:"
echo "   cd /opt/bitcoin && ./scripts/status.sh"
echo ""
echo "5. 📱 Get family access info:"
echo "   ./scripts/access-info.sh"
echo ""
echo -e "${BLUE}💰 Cost Savings:${NC}"
echo "Old Contabo: \$54/month"
echo "New OVH:     \$34/month"
echo "Savings:     \$20/month (\$240/year!)"
echo ""
echo -e "${GREEN}🏠 Your family Bitcoin infrastructure is ready!${NC}"
echo ""

# Show initial status
./scripts/status.sh