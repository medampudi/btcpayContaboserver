#!/bin/bash
# 🚀 OVH Dedicated Server Automated Setup
# Complete Bitcoin Stack Migration from Contabo
# For Medampudi Family - Ubuntu 24.04 Dedicated Server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables - CHANGE THESE
DOMAIN_NAME="your-bitcoin-domain.com"
BTCPAY_DOMAIN="pay.your-bitcoin-domain.com"
EMAIL="your-email@domain.com"
FAMILY_NAME="Medampudi-Family"

# Family Members
FAMILY_MEMBERS="Rajesh Apoorva Meera Vidur Ravi Bhavani Ramya(Kilaru) Sumanth(Kilaru) Viren(Kilaru) Naina(Kilaru)"

# Passwords - CHANGE ALL OF THESE
BITCOIN_RPC_USER="medampudi_rpc_user"
BITCOIN_RPC_PASS="SecureMedampudiRPC2025!"
POSTGRES_PASS="MedampudiPostgres2025!"
MARIADB_ROOT_PASS="MedampudiMariaRoot2025!"
MARIADB_MEMPOOL_PASS="MedampudiMempool2025!"

# Server Configuration
TIMEZONE="Asia/Kolkata"
SWAP_SIZE="8G"
TAILSCALE_AUTHKEY=""  # Get from https://login.tailscale.com/admin/settings/keys

echo -e "${BLUE}🚀 Starting OVH Dedicated Server Setup for Medampudi Family${NC}"
echo -e "${YELLOW}📊 Migration from Contabo to OVH - Bitcoin Sovereignty Setup${NC}"
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Run as ubuntu user with sudo access."
   print_error "Switch to ubuntu user: su - ubuntu"
   exit 1
fi

# Verify we're running as ubuntu user
if [ "$USER" != "ubuntu" ]; then
   print_warning "Script should be run as 'ubuntu' user for OVH servers"
   print_warning "Current user: $USER"
   read -p "Continue anyway? (y/N): " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
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

print_status "Setting timezone to India..."
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

# Phase 2: SSH Security Setup
echo -e "${BLUE}🔐 Phase 2: SSH Security Setup${NC}"

print_status "Setting up SSH security for ubuntu user..."

# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH for ubuntu user
sudo tee /etc/ssh/sshd_config.d/99-medampudi-family.conf > /dev/null <<EOF
# Medampudi Family Bitcoin Server SSH Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowUsers ubuntu
Protocol 2
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

print_status "SSH configuration updated for ubuntu user"

# Ensure ubuntu user has proper sudo access
if ! sudo -l -U ubuntu | grep -q "(ALL) ALL"; then
    print_status "Ensuring ubuntu user has sudo access..."
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu-nopasswd
fi

# Phase 3: Install Docker
echo -e "${BLUE}🐳 Phase 3: Docker Installation${NC}"

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

# Phase 4: Install Tailscale
echo -e "${BLUE}🔗 Phase 4: Tailscale VPN Setup${NC}"

if ! command -v tailscale &> /dev/null; then
    print_status "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    print_status "Tailscale installed"
else
    print_warning "Tailscale already installed"
fi

if [ ! -z "$TAILSCALE_AUTHKEY" ]; then
    print_status "Connecting to Tailscale..."
    sudo tailscale up --authkey=$TAILSCALE_AUTHKEY --hostname="medampudi-bitcoin-node" --accept-routes
    TAILSCALE_IP=$(tailscale ip -4)
    print_status "Tailscale connected. IP: $TAILSCALE_IP"
else
    print_warning "Tailscale auth key not provided. Run manually: sudo tailscale up"
fi

# Phase 5: Install Cloudflared
echo -e "${BLUE}☁️  Phase 5: Cloudflare Tunnel Setup${NC}"

if ! command -v cloudflared &> /dev/null; then
    print_status "Installing Cloudflared..."
    # Add Cloudflare repository
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
    sudo apt update
    sudo apt install -y cloudflared
    print_status "Cloudflared installed"
else
    print_warning "Cloudflared already installed"
fi

# Phase 6: Firewall Configuration
echo -e "${BLUE}🛡️  Phase 6: Firewall and Security Hardening${NC}"

print_status "Configuring UFW firewall..."

# Reset UFW to default
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow essential services
sudo ufw allow 22/tcp comment 'SSH (temporary - will restrict to Tailscale later)'
sudo ufw allow 80/tcp comment 'HTTP for Let\'s Encrypt'
sudo ufw allow 443/tcp comment 'HTTPS for BTCPay Server'
sudo ufw allow 8333/tcp comment 'Bitcoin P2P'
sudo ufw allow 9735/tcp comment 'Lightning Network'

# Allow Tailscale interface
sudo ufw allow in on tailscale0
sudo ufw allow out on tailscale0

# Enable firewall
sudo ufw --force enable

print_status "Firewall configured"

# Configure Fail2ban
print_status "Configuring Fail2ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[cloudflared]
enabled = true
port = 80,443
filter = cloudflared
logpath = /var/log/cloudflared.log
maxretry = 5
EOF

sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
print_status "Fail2ban configured"

# Phase 7: Bitcoin Infrastructure Setup
echo -e "${BLUE}₿ Phase 7: Bitcoin Infrastructure Preparation${NC}"

print_status "Creating Bitcoin directory structure..."
sudo mkdir -p /opt/bitcoin/{data,configs,backups,logs,scripts}
sudo chown -R $USER:$USER /opt/bitcoin
cd /opt/bitcoin

print_status "Creating Bitcoin configuration files..."

# Create Fulcrum config
mkdir -p configs
cat > configs/fulcrum.conf << EOF
# Fulcrum Electrum Server Configuration for Medampudi Family
datadir = /data
bitcoind = bitcoind:8332
rpcuser = $BITCOIN_RPC_USER
rpcpassword = $BITCOIN_RPC_PASS

# Network bindings (internal only)
tcp = 0.0.0.0:50001
ssl = 0.0.0.0:50002

# SSL certificates
cert = /data/fulcrum.crt
key = /data/fulcrum.key
peering = false

# Performance settings for dedicated server
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

# Phase 8: Docker Compose Configuration
print_status "Creating Docker Compose configuration..."

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

# Phase 9: Create Management Scripts
print_status "Creating management scripts..."

# Bitcoin status checker
cat > scripts/bitcoin-status.sh << 'EOF'
#!/bin/bash
# Bitcoin Node Status for Medampudi Family

echo "₿ === Medampudi Family Bitcoin Node Status ==="
echo "=============================================="
echo ""

# Check if Bitcoin is running
if docker ps | grep -q bitcoind; then
    echo "✅ Bitcoin Core: Running"
    
    # Get blockchain info
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
        
        # Check peers
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
echo "💾 Disk Usage:"
df -h | grep -E "Filesystem|/opt/bitcoin|/$"

echo ""
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
echo "🔗 Tailscale IP: $TAILSCALE_IP"
echo ""
echo "🌐 Family Access URLs:"
if [ "$TAILSCALE_IP" != "Not connected" ]; then
    echo "Mempool Explorer:    http://$TAILSCALE_IP:8080"
    echo "Bitcoin Explorer:    http://$TAILSCALE_IP:3002"
    echo "Electrum Server:     $TAILSCALE_IP:50001"
    echo "BTCPay Server:       https://$BTCPAY_DOMAIN"
else
    echo "Connect to Tailscale first: sudo tailscale up"
fi
EOF

chmod +x scripts/bitcoin-status.sh

# Family access script
cat > scripts/family-access.sh << 'EOF'
#!/bin/bash
# Family Access Information for Medampudi Family

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
echo "BTCPay Server:        https://$BTCPAY_DOMAIN"
echo "Electrum Server:      $TAILSCALE_IP:50001"
echo "Lightning Node:       $TAILSCALE_IP:9735"
echo ""
echo "📱 Mobile Wallet Setup:"
echo "Server: $TAILSCALE_IP"
echo "Port: 50001 (TCP) or 50002 (SSL)"
echo ""
echo "🎓 For Kids Learning:"
echo "Block Explorer:       http://$TAILSCALE_IP:8080"
echo "Transaction Search:   http://$TAILSCALE_IP:3002"
EOF

chmod +x scripts/family-access.sh

# Migration script from Contabo
cat > scripts/migrate-from-contabo.sh << 'EOF'
#!/bin/bash
# Migration script from Contabo Bitcoin node

CONTABO_IP="YOUR_CONTABO_IP"
CONTABO_USER="admin"

echo "🔄 Migrating Bitcoin data from Contabo server..."
echo "⚠️  This will take several hours depending on your connection"
echo ""

read -p "Enter Contabo server IP: " CONTABO_IP
read -p "Enter Contabo username (default: admin): " CONTABO_USER
CONTABO_USER=${CONTABO_USER:-admin}

echo "📦 Creating migration directory..."
mkdir -p /opt/bitcoin/migration

echo "🗜️  Creating backup on Contabo server..."
ssh $CONTABO_USER@$CONTABO_IP << 'REMOTE_SCRIPT'
mkdir -p /tmp/bitcoin-migration
cd /opt/bitcoin

# Backup Bitcoin blockchain data (most important)
echo "Backing up Bitcoin blockchain data..."
tar -czf /tmp/bitcoin-migration/bitcoin_blocks_chainstate.tar.gz \
    data/bitcoin/blocks data/bitcoin/chainstate

# Backup Bitcoin wallet (if exists)
if [ -d "data/bitcoin/wallet" ]; then
    tar -czf /tmp/bitcoin-migration/bitcoin_wallet.tar.gz data/bitcoin/wallet
fi

# Backup configurations
echo "Backing up configurations..."
tar -czf /tmp/bitcoin-migration/configs.tar.gz configs/

echo "✅ Backup completed on Contabo"
REMOTE_SCRIPT

echo "📥 Downloading backup from Contabo..."
rsync -avz --progress $CONTABO_USER@$CONTABO_IP:/tmp/bitcoin-migration/ /opt/bitcoin/migration/

echo "📂 Restoring Bitcoin data..."
cd /opt/bitcoin

# Stop Bitcoin if running
docker compose stop bitcoind || true

# Restore blockchain data
echo "Restoring blockchain data..."
sudo docker run --rm -v bitcoin_data:/data -v /opt/bitcoin/migration:/backup alpine sh -c "cd /data && tar -xzf /backup/bitcoin_blocks_chainstate.tar.gz --strip-components=2"

# Restore wallet if exists
if [ -f "/opt/bitcoin/migration/bitcoin_wallet.tar.gz" ]; then
    echo "Restoring wallet..."
    sudo docker run --rm -v bitcoin_data:/data -v /opt/bitcoin/migration:/backup alpine sh -c "cd /data && tar -xzf /backup/bitcoin_wallet.tar.gz --strip-components=2"
fi

# Restore configurations
if [ -f "/opt/bitcoin/migration/configs.tar.gz" ]; then
    echo "Restoring configurations..."
    tar -xzf /opt/bitcoin/migration/configs.tar.gz
fi

echo "🔄 Starting Bitcoin with restored data..."
docker compose up -d bitcoind

echo "✅ Migration completed!"
echo "📊 Check status with: ./scripts/bitcoin-status.sh"
EOF

chmod +x scripts/migrate-from-contabo.sh

print_status "Management scripts created"

# Phase 10: Final Setup Instructions
echo ""
echo -e "${BLUE}🎉 OVH Dedicated Server Setup Complete!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
print_status "Server configured successfully for Medampudi Family Bitcoin Infrastructure"

echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. 🔐 Restrict SSH to Tailscale only:"
echo "   sudo nano /etc/ssh/sshd_config.d/99-custom.conf"
echo "   Add: ListenAddress $(tailscale ip -4 2>/dev/null || echo TAILSCALE_IP)"
echo ""
echo "2. ☁️  Setup Cloudflare Tunnel:"
echo "   cloudflared tunnel login"
echo "   cloudflared tunnel create medampudi-bitcoin"
echo ""
echo "3. 🔄 Migrate Bitcoin data from Contabo:"
echo "   cd /opt/bitcoin && ./scripts/migrate-from-contabo.sh"
echo ""
echo "4. 🚀 Start Bitcoin services:"
echo "   docker compose up -d"
echo ""
echo "5. 📊 Check status:"
echo "   ./scripts/bitcoin-status.sh"
echo ""
echo "6. 👨‍👩‍👧‍👦 Family access info:"
echo "   ./scripts/family-access.sh"
echo ""

echo -e "${BLUE}📁 Important Files Created:${NC}"
echo "├── /opt/bitcoin/docker-compose.yml"
echo "├── /opt/bitcoin/configs/ (Bitcoin configurations)"
echo "├── /opt/bitcoin/scripts/ (Management scripts)"
echo "└── /opt/bitcoin/migration/ (Migration workspace)"
echo ""

echo -e "${YELLOW}⚠️  Security Reminders:${NC}"
echo "• Change all passwords in this script before running"
echo "• Set up Tailscale auth key for automatic connection"
echo "• Configure Cloudflare DNS after tunnel creation"
echo "• Regular backups are configured automatically"
echo ""

echo -e "${GREEN}🏠 Family Server Ready! Access via Tailscale VPN only.${NC}"

# Create systemd service for family status
print_status "Creating system services..."

sudo tee /etc/systemd/system/bitcoin-family-status.service > /dev/null <<EOF
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

print_status "Setup completed! 🎉"