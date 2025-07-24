#!/bin/bash
set -eo pipefail

# =============================================================================
# Bitcoin Sovereignty Complete Setup for Ubuntu 22.04/24.04
# Consolidated script with all learnings from medampudi setup
# =============================================================================

VERSION="2.0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_section() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }

# =============================================================================
# PHASE DETECTION
# =============================================================================

detect_phase() {
    if [[ ! -f "/opt/bitcoin/.phase" ]]; then
        echo "1"
    else
        cat /opt/bitcoin/.phase
    fi
}

save_phase() {
    mkdir -p /opt/bitcoin
    echo "$1" > /opt/bitcoin/.phase
}

# =============================================================================
# CONFIGURATION
# =============================================================================

load_config() {
    # Load from setup-config.env if exists
    if [[ -f "$SCRIPT_DIR/setup-config.env" ]]; then
        log_info "Loading configuration from setup-config.env..."
        source "$SCRIPT_DIR/setup-config.env"
    else
        log_error "Configuration file setup-config.env not found!"
        log_info "Creating template configuration file..."
        create_config_template
        exit 1
    fi
}

create_config_template() {
    cat > "$SCRIPT_DIR/setup-config.env" << 'EOF'
# Bitcoin Sovereignty Setup Configuration
# Edit this file before running bitcoin-complete-setup.sh

# Domain Configuration
DOMAIN_NAME="your-domain.com"
BTCPAY_DOMAIN="pay.your-domain.com"
EMAIL="your-email@gmail.com"
FAMILY_NAME="YourFamily"

# Server Configuration
SERVER_HOSTNAME="bitcoin-node"
ADMIN_USER="admin"
SWAP_SIZE="8G"
TIMEZONE="Asia/Kolkata"

# CHANGE ALL PASSWORDS!
BITCOIN_RPC_USER="bitcoin_rpc_user"
BITCOIN_RPC_PASS="CHANGE_THIS_StrongPassword123!"
POSTGRES_PASS="CHANGE_THIS_PostgresPassword456!"
MARIADB_ROOT_PASS="CHANGE_THIS_MariaRootPass789!"
MARIADB_MEMPOOL_PASS="CHANGE_THIS_MempoolPass321!"

# Get from: https://login.tailscale.com/admin/settings/keys
TAILSCALE_AUTHKEY=""

# Optional: Cloudflare API for automated tunnel
CLOUDFLARE_API_TOKEN=""
CLOUDFLARE_ZONE_ID=""
CLOUDFLARE_ACCOUNT_ID=""

# Family Members (space-separated)
FAMILY_MEMBERS="Parent1 Parent2 Child1 Child2"

# Performance (adjust based on RAM)
BITCOIN_DBCACHE="4000"      # 25% of RAM in MB
BITCOIN_MAXMEMPOOL="2000"   # Max mempool in MB
EOF
    
    log_info "Template created at setup-config.env"
    log_info "Please edit it with your values and run the script again"
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_system() {
    log_section "System Validation"
    
    # Check if root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo su -)"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -E "Ubuntu (22\.04|24\.04)" /etc/os-release > /dev/null; then
        log_warning "This script is tested on Ubuntu 22.04/24.04"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=$((2 * 1024 * 1024 * 1024)) # 2TB in KB
    if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
        log_warning "Less than 2TB available. Bitcoin requires significant space."
        log_warning "Available: $(df -h / | awk 'NR==2 {print $4}')"
    fi
    
    log_success "System validation passed"
}

# =============================================================================
# PHASE 1: INITIAL SETUP
# =============================================================================

phase1_initial_setup() {
    log_section "Phase 1: Initial System Setup"
    
    # Set hostname and timezone
    hostnamectl set-hostname $SERVER_HOSTNAME
    timedatectl set-timezone $TIMEZONE
    
    # Update system
    log_info "Updating system packages..."
    apt update && apt upgrade -y
    
    # Install essential packages
    log_info "Installing essential packages..."
    apt install -y \
        curl wget git vim htop ncdu tree \
        ufw fail2ban net-tools dnsutils \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        jq bc moreutils unzip \
        python3-pip mailutils
    
    # Configure swap
    if [[ ! -f /swapfile ]]; then
        log_info "Creating swap file..."
        fallocate -l $SWAP_SIZE /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        # Optimize swappiness
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        sysctl -p
    fi
    
    save_phase 2
    log_success "Phase 1 complete"
}

# =============================================================================
# PHASE 2: USER AND SECURITY
# =============================================================================

phase2_security() {
    log_section "Phase 2: User and Security Setup"
    
    # Create admin user
    if ! id "$ADMIN_USER" &>/dev/null; then
        log_info "Creating admin user..."
        useradd -m -s /bin/bash $ADMIN_USER
        usermod -aG sudo $ADMIN_USER
    else
        log_info "User $ADMIN_USER already exists"
        # Ensure user is in correct groups
        usermod -aG sudo $ADMIN_USER || true
    fi
    
    # Setup SSH directory
    if [[ ! -d /home/$ADMIN_USER/.ssh ]]; then
        mkdir -p /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        # Fix ownership with correct group
        USER_GROUP=$(id -gn $ADMIN_USER)
        chown -R $ADMIN_USER:$USER_GROUP /home/$ADMIN_USER/.ssh
    fi
    
    # Configure fail2ban
    log_info "Configuring fail2ban..."
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    systemctl restart fail2ban
    
    save_phase 3
    log_success "Phase 2 complete"
}

# =============================================================================
# PHASE 3: TAILSCALE VPN
# =============================================================================

phase3_tailscale() {
    log_section "Phase 3: Tailscale VPN Setup"
    
    # Install Tailscale
    if ! command -v tailscale &>/dev/null; then
        log_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    else
        log_info "Tailscale already installed"
    fi
    
    # Connect Tailscale
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Connecting Tailscale..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --accept-routes || log_warning "Tailscale may already be connected"
    else
        log_warning "No Tailscale auth key provided"
        log_info "Please run manually: tailscale up"
    fi
    
    # Get Tailscale IP
    sleep 5
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$TAILSCALE_IP" ]]; then
        log_success "Tailscale connected: $TAILSCALE_IP"
        echo "export TAILSCALE_IP=$TAILSCALE_IP" >> /opt/bitcoin/.env
    fi
    
    save_phase 4
    log_success "Phase 3 complete"
}

# =============================================================================
# PHASE 4: FIREWALL
# =============================================================================

phase4_firewall() {
    log_section "Phase 4: Firewall Configuration"
    
    # Get current SSH connection
    CURRENT_SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    
    # Configure UFW
    log_info "Configuring firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Essential services
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8333/tcp comment 'Bitcoin P2P'
    ufw allow 9735/tcp comment 'Lightning'
    
    # Allow current SSH to prevent lockout
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        ufw allow from $CURRENT_SSH_IP to any port 22 comment 'Current SSH'
    fi
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable firewall
    echo "y" | ufw enable
    
    save_phase 5
    log_success "Phase 4 complete"
}

# =============================================================================
# PHASE 5: DOCKER
# =============================================================================

phase5_docker() {
    log_section "Phase 5: Docker Installation"
    
    if ! command -v docker &>/dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
    else
        log_info "Docker already installed"
    fi
    
    # Add admin user to docker group
    usermod -aG docker $ADMIN_USER || true
    
    # Install docker-compose
    if ! docker compose version &>/dev/null 2>&1; then
        log_info "Installing docker-compose..."
        apt install -y docker-compose-v2
    fi
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    save_phase 6
    log_success "Phase 5 complete"
}

# =============================================================================
# PHASE 6: BITCOIN SETUP
# =============================================================================

phase6_bitcoin() {
    log_section "Phase 6: Bitcoin Core Setup"
    
    # Create directories
    log_info "Creating Bitcoin directories..."
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p /opt/bitcoin/mysql
    
    # Create configurations
    create_bitcoin_configs
    
    # Create docker-compose
    create_docker_compose
    
    # Create monitoring scripts
    create_monitoring_scripts
    
    # Fix ownership
    USER_GROUP=$(id -gn $ADMIN_USER 2>/dev/null || echo $ADMIN_USER)
    chown -R $ADMIN_USER:$USER_GROUP /opt/bitcoin
    
    # Start Bitcoin Core
    log_info "Starting Bitcoin Core..."
    cd /opt/bitcoin
    docker compose up -d bitcoind
    
    save_phase 7
    log_success "Phase 6 complete - Bitcoin Core is now syncing!"
}

# =============================================================================
# PHASE 7: WAIT FOR SYNC
# =============================================================================

phase7_wait_sync() {
    log_section "Phase 7: Bitcoin Sync Status"
    
    # Check sync status
    if ! docker ps | grep -q bitcoind; then
        log_error "Bitcoin Core is not running!"
        exit 1
    fi
    
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo 2>/dev/null || echo "{}")
    PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress // 0')
    PROGRESS_PCT=$(awk "BEGIN {printf \"%.1f\", $PROGRESS * 100}")
    
    log_info "Bitcoin sync progress: ${PROGRESS_PCT}%"
    
    if (( $(awk "BEGIN {print ($PROGRESS < 0.9)}") )); then
        log_warning "Bitcoin needs to sync to at least 90% before continuing"
        log_info "Current progress: ${PROGRESS_PCT}%"
        log_info ""
        log_info "Check sync status with: ./check-sync.sh"
        log_info "When ready, run this script again to continue"
        exit 0
    fi
    
    save_phase 8
    log_success "Bitcoin is synced! Continuing setup..."
}

# =============================================================================
# PHASE 8: COMPLETE SETUP
# =============================================================================

phase8_complete() {
    log_section "Phase 8: Completing Bitcoin Stack"
    
    # Load Tailscale IP if not set
    if [[ -z "$TAILSCALE_IP" ]]; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "127.0.0.1")
    fi
    
    # Update docker-compose with all services
    create_full_docker_compose
    
    # Start all services
    log_info "Starting all services..."
    cd /opt/bitcoin
    
    # Start databases
    docker compose up -d postgres mempool-db
    sleep 10
    
    # Start remaining services
    docker compose up -d fulcrum mempool-api mempool-web btc-rpc-explorer
    
    # Setup cron jobs
    setup_cron_jobs
    
    save_phase 9
    log_success "Phase 8 complete - All services running!"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

create_bitcoin_configs() {
    log_info "Creating Bitcoin configurations..."
    
    # Fulcrum config
    cat > /opt/bitcoin/configs/fulcrum.conf << EOF
datadir = /data
bitcoind = bitcoind:8332
rpcuser = ${BITCOIN_RPC_USER}
rpcpassword = ${BITCOIN_RPC_PASS}

tcp = 0.0.0.0:50001
ssl = 0.0.0.0:50002

cert = /data/fulcrum.crt
key = /data/fulcrum.key
peering = false

fast-sync = 1
db_max_open_files = 500
db_mem = 4000.0
EOF

    # Mempool config
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

create_docker_compose() {
    log_info "Creating initial docker-compose.yml..."
    
    cat > /opt/bitcoin/docker-compose.yml << EOF
version: '3.8'

networks:
  bitcoin:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

services:
  bitcoind:
    image: btcpayserver/bitcoin:26.0
    container_name: bitcoind
    restart: unless-stopped
    networks:
      bitcoin:
        ipv4_address: 172.25.0.10
    volumes:
      - ./data/bitcoin:/data
    environment:
      BITCOIN_NETWORK: mainnet
      BITCOIN_EXTRA_ARGS: |
        rpcuser=${BITCOIN_RPC_USER}
        rpcpassword=${BITCOIN_RPC_PASS}
        rpcallowip=172.0.0.0/8
        rpcallowip=127.0.0.1
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
        dbcache=${BITCOIN_DBCACHE}
        maxmempool=${BITCOIN_MAXMEMPOOL}
    ports:
      - "8333:8333"
EOF
}

create_full_docker_compose() {
    log_info "Creating complete docker-compose.yml..."
    
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
        rpcallowip=172.0.0.0/8
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
        zmqpubrawblock=tcp://0.0.0.0:28332
        zmqpubrawtx=tcp://0.0.0.0:28333
        dbcache=${BITCOIN_DBCACHE}
        maxmempool=${BITCOIN_MAXMEMPOOL}
    ports:
      - "8333:8333"
      - "${TAILSCALE_IP}:8332:8332"

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

create_monitoring_scripts() {
    log_info "Creating monitoring scripts..."
    
    # Status script
    cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
clear
echo "=== Bitcoin Sovereignty Stack Status ==="
echo "========================================"
echo ""
echo "System: $(hostname)"
echo "Uptime: $(uptime -p)"
if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    echo "Tailscale IP: $(tailscale ip -4)"
fi
echo ""
echo "Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin|fulcrum|mempool|explorer|postgres"
echo ""
if docker ps | grep -q bitcoind; then
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=__RPC_USER__ -rpcpassword=__RPC_PASS__ getblockchaininfo 2>/dev/null || echo "{}")
    if [ -n "$SYNC_INFO" ] && [ "$SYNC_INFO" != "{}" ]; then
        PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress')
        BLOCKS=$(echo $SYNC_INFO | jq -r '.blocks')
        HEADERS=$(echo $SYNC_INFO | jq -r '.headers')
        PCT=$(echo "scale=1; $PROGRESS * 100" | bc)
        echo "Bitcoin Sync: ${PCT}% ($BLOCKS/$HEADERS blocks)"
    fi
fi
EOF

    # Replace placeholders
    sed -i "s/__RPC_USER__/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/status.sh
    sed -i "s/__RPC_PASS__/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/status.sh
    
    # Check sync script
    cat > /opt/bitcoin/scripts/check-sync.sh << 'EOF'
#!/bin/bash
if ! docker ps | grep -q bitcoind; then
    echo "Bitcoin Core is not running!"
    exit 1
fi

SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=__RPC_USER__ -rpcpassword=__RPC_PASS__ getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Bitcoin Core is still starting..."
    exit 1
fi

PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress')
PCT=$(echo "scale=1; $PROGRESS * 100" | bc)
echo "Bitcoin sync: ${PCT}%"

if (( $(echo "$PROGRESS >= 0.9" | bc -l) )); then
    echo "✅ Ready for complete setup!"
else
    echo "⏳ Keep waiting..."
fi
EOF

    # Replace placeholders
    sed -i "s/__RPC_USER__/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/check-sync.sh
    sed -i "s/__RPC_PASS__/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/check-sync.sh
    
    chmod +x /opt/bitcoin/scripts/*.sh
}

setup_cron_jobs() {
    log_info "Setting up automated tasks..."
    
    # Create backup script
    cat > /opt/bitcoin/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/bitcoin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup configs
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz /opt/bitcoin/configs /opt/bitcoin/docker-compose.yml

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

    chmod +x /opt/bitcoin/scripts/backup.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null || true; echo "0 3 * * * /opt/bitcoin/scripts/backup.sh > /opt/bitcoin/logs/backup.log 2>&1") | crontab -
}

# =============================================================================
# COMPLETION
# =============================================================================

show_completion() {
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
    
    clear
    echo "=========================================="
    echo "🎉 Bitcoin Sovereignty Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Version: $VERSION"
    echo "Domain: $DOMAIN_NAME"
    echo "BTCPay: $BTCPAY_DOMAIN"
    echo "Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "📊 Access your services (via Tailscale):"
    echo "- Mempool Explorer: http://$TAILSCALE_IP:8080"
    echo "- BTC RPC Explorer: http://$TAILSCALE_IP:3002"
    echo "- Electrum Server: $TAILSCALE_IP:50001"
    echo ""
    echo "📱 Wallet Configuration:"
    echo "- Server: $TAILSCALE_IP"
    echo "- Port: 50001"
    echo "- SSL: Disabled (secure via Tailscale)"
    echo ""
    echo "🔧 Useful commands:"
    echo "- Check status: /opt/bitcoin/scripts/status.sh"
    echo "- View logs: docker logs [service-name]"
    echo "- Restart service: docker compose restart [service-name]"
    echo ""
    echo "📁 Important locations:"
    echo "- Configuration: $SCRIPT_DIR/setup-config.env"
    echo "- Bitcoin data: /opt/bitcoin/data/"
    echo "- Scripts: /opt/bitcoin/scripts/"
    echo ""
    echo "🔐 Security notes:"
    echo "- All services are private (Tailscale only)"
    echo "- Firewall configured with minimal exposure"
    echo "- Automatic backups run daily at 3 AM"
    echo ""
    
    # Save completion info
    cat > /opt/bitcoin/README.md << EOF
# Bitcoin Sovereignty Infrastructure

Setup completed on: $(date)
Version: $VERSION
Domain: $DOMAIN_NAME
Tailscale IP: $TAILSCALE_IP

## Services Running
- Bitcoin Core (Port 8333)
- Fulcrum Electrum Server (Port 50001)
- Mempool Explorer (Port 8080)
- BTC RPC Explorer (Port 3002)
- PostgreSQL Database
- MariaDB Database

## Access
All services are accessible only via Tailscale VPN.
EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    clear
    echo "============================================"
    echo "Bitcoin Sovereignty Setup v$VERSION"
    echo "============================================"
    echo ""
    
    # Load configuration
    load_config
    
    # Validate system
    validate_system
    
    # Detect current phase
    CURRENT_PHASE=$(detect_phase)
    log_info "Current phase: $CURRENT_PHASE"
    
    # Execute phases
    case $CURRENT_PHASE in
        1) phase1_initial_setup ;&
        2) phase2_security ;&
        3) phase3_tailscale ;&
        4) phase4_firewall ;&
        5) phase5_docker ;&
        6) phase6_bitcoin ;&
        7) phase7_wait_sync ;&
        8) phase8_complete ;&
        9) show_completion ;;
    esac
}

# Run main
main "$@"