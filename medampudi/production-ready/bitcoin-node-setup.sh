#!/bin/bash
set -eo pipefail

# =============================================================================
# Bitcoin Node Complete Setup Script for Ubuntu 22.04
# Version: 3.0 - Production Ready
# =============================================================================

VERSION="3.0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_section() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

check_config() {
    if [[ ! -f "$SCRIPT_DIR/setup-config.env" ]]; then
        log_error "Configuration file not found!"
        log_info "Creating from template..."
        
        if [[ -f "$SCRIPT_DIR/setup-config-template.env" ]]; then
            cp "$SCRIPT_DIR/setup-config-template.env" "$SCRIPT_DIR/setup-config.env"
            log_success "Created setup-config.env from template"
            log_warning "Please edit setup-config.env with your values and run again"
            exit 1
        else
            log_error "Template file not found!"
            exit 1
        fi
    fi
    
    # Load configuration
    source "$SCRIPT_DIR/setup-config.env"
    
    # Validate critical settings
    if [[ "$DOMAIN_NAME" == "your-domain.com" ]]; then
        log_error "Please update DOMAIN_NAME in setup-config.env"
        exit 1
    fi
    
    if [[ "$BITCOIN_RPC_PASS" == "ChangeMeToSecurePassword123" ]]; then
        log_error "Please change default passwords in setup-config.env"
        exit 1
    fi
}

# =============================================================================
# SYSTEM VALIDATION
# =============================================================================

validate_system() {
    log_section "System Validation"
    
    # Check if root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Run: sudo su - (or login as root)"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        log_warning "This script is tested on Ubuntu 22.04"
        read -p "Continue on this system? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check minimum requirements
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 8 ]]; then
        log_warning "Less than 8GB RAM detected. Minimum 16GB recommended."
    fi
    
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 1000 ]]; then
        log_warning "Less than 1TB free space. 2TB+ recommended for Bitcoin."
    fi
    
    log_success "System validation complete"
}

# =============================================================================
# INITIAL SETUP
# =============================================================================

initial_setup() {
    log_section "Initial System Setup"
    
    # Set hostname and timezone
    hostnamectl set-hostname $SERVER_HOSTNAME
    timedatectl set-timezone $TIMEZONE
    
    # Update system
    log_info "Updating system packages..."
    apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y
    
    # Install essential packages
    log_info "Installing essential packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl wget git vim htop ncdu tree \
        ufw fail2ban net-tools dnsutils \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        jq bc moreutils unzip python3-pip
    
    # Configure swap if needed
    if [[ ! -f /swapfile ]]; then
        log_info "Creating ${SWAP_SIZE} swap file..."
        fallocate -l $SWAP_SIZE /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        sysctl -p
    fi
    
    log_success "Initial setup complete"
}

# =============================================================================
# USER SETUP
# =============================================================================

setup_user() {
    log_section "User Configuration"
    
    # Handle admin user
    if ! id "$ADMIN_USER" &>/dev/null; then
        log_info "Creating admin user: $ADMIN_USER"
        useradd -m -s /bin/bash $ADMIN_USER
        usermod -aG sudo $ADMIN_USER
    else
        log_info "User $ADMIN_USER already exists"
    fi
    
    # Ensure SSH directory
    USER_HOME="/home/$ADMIN_USER"
    if [[ ! -d "$USER_HOME/.ssh" ]]; then
        mkdir -p "$USER_HOME/.ssh"
        chmod 700 "$USER_HOME/.ssh"
        touch "$USER_HOME/.ssh/authorized_keys"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
    fi
    
    # Fix ownership
    USER_GROUP=$(id -gn $ADMIN_USER)
    chown -R $ADMIN_USER:$USER_GROUP "$USER_HOME/.ssh"
    
    log_success "User configuration complete"
}

# =============================================================================
# SECURITY SETUP
# =============================================================================

setup_security() {
    log_section "Security Configuration"
    
    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
maxretry = 3
EOF
    
    systemctl restart fail2ban
    
    # Configure firewall
    log_info "Setting up firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Essential ports
    ufw allow $SSH_PORT/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8333/tcp comment 'Bitcoin'
    ufw allow 9735/tcp comment 'Lightning'
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    echo "y" | ufw enable
    
    log_success "Security configured"
}

# =============================================================================
# TAILSCALE SETUP
# =============================================================================

setup_tailscale() {
    log_section "Tailscale VPN Setup"
    
    # Install Tailscale
    if ! command -v tailscale &>/dev/null; then
        log_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    # Connect if auth key provided
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Connecting Tailscale..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --accept-routes || true
        sleep 5
        
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [[ -n "$TAILSCALE_IP" ]]; then
            log_success "Tailscale connected: $TAILSCALE_IP"
            echo "$TAILSCALE_IP" > /opt/bitcoin/.tailscale_ip
        fi
    else
        log_warning "No Tailscale auth key provided"
        log_info "Run manually: tailscale up"
    fi
}

# =============================================================================
# DOCKER SETUP
# =============================================================================

setup_docker() {
    log_section "Docker Installation"
    
    if ! command -v docker &>/dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
    fi
    
    # Add user to docker group
    usermod -aG docker $ADMIN_USER || true
    
    # Install docker-compose
    if ! docker compose version &>/dev/null 2>&1; then
        apt install -y docker-compose-v2
    fi
    
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker ready"
}

# =============================================================================
# BITCOIN STACK SETUP
# =============================================================================

setup_bitcoin() {
    log_section "Bitcoin Stack Setup"
    
    # Create directory structure
    log_info "Creating directories..."
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p /opt/bitcoin/mysql
    
    # Create configurations
    create_configs
    
    # Create docker-compose
    create_docker_compose
    
    # Create scripts
    create_scripts
    
    # Fix ownership
    USER_GROUP=$(id -gn $ADMIN_USER 2>/dev/null || echo $ADMIN_USER)
    chown -R $ADMIN_USER:$USER_GROUP /opt/bitcoin
    
    # Start Bitcoin Core
    log_info "Starting Bitcoin Core..."
    cd /opt/bitcoin
    docker compose up -d bitcoind
    
    log_success "Bitcoin Core started - will take 2-5 days to sync"
}

# =============================================================================
# CONFIGURATION FILES
# =============================================================================

create_configs() {
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
    # Get Tailscale IP if available
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "127.0.0.1")
    
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
  mempool_data:

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
        maxconnections=${BITCOIN_MAX_CONNECTIONS}
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
    profiles:
      - full

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
    profiles:
      - full

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
    profiles:
      - full

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
    profiles:
      - full

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
    profiles:
      - full

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
    profiles:
      - full
EOF
}

create_scripts() {
    # Check sync script
    cat > /opt/bitcoin/scripts/check-sync.sh << 'EOF'
#!/bin/bash
# Check Bitcoin sync status

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load config
CONFIG_FILE="/root/setup-config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Config file not found!"
    exit 1
fi

# Check if running
if ! docker ps | grep -q bitcoind; then
    echo "Bitcoin Core is not running!"
    exit 1
fi

# Get sync info
INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=$BITCOIN_RPC_USER -rpcpassword=$BITCOIN_RPC_PASS getblockchaininfo 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Bitcoin Core is starting up..."
    exit 1
fi

# Parse info
BLOCKS=$(echo $INFO | jq -r '.blocks')
HEADERS=$(echo $INFO | jq -r '.headers')
PROGRESS=$(echo $INFO | jq -r '.verificationprogress')
PCT=$(echo "scale=1; $PROGRESS * 100" | bc)

echo -e "${YELLOW}Bitcoin Sync Status${NC}"
echo "==================="
echo "Progress: ${PCT}%"
echo "Blocks: $BLOCKS / $HEADERS"

if (( $(echo "$PROGRESS >= 0.9" | bc -l) )); then
    echo -e "\n${GREEN}✓ Bitcoin is synced enough!${NC}"
    echo "Run: ./enable-all-services.sh"
else
    echo -e "\n⏳ Still syncing... Check again later."
fi
EOF

    # Enable all services script
    cat > /opt/bitcoin/scripts/enable-all-services.sh << 'EOF'
#!/bin/bash
# Enable all services after Bitcoin sync

cd /opt/bitcoin

echo "Starting all services..."
docker compose --profile full up -d

echo ""
echo "All services starting! Wait a few minutes then check:"
echo "./status.sh"
EOF

    # Status script
    cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
# Show system status

clear
echo "=== Bitcoin Node Status ==="
echo "=========================="
echo ""
echo "System: $(hostname)"
if [[ -f /opt/bitcoin/.tailscale_ip ]]; then
    echo "Tailscale IP: $(cat /opt/bitcoin/.tailscale_ip)"
fi
echo ""
echo "Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin|fulcrum|mempool|explorer|postgres"
echo ""
echo "Run ./check-sync.sh for Bitcoin sync status"
EOF

    chmod +x /opt/bitcoin/scripts/*.sh
}

# =============================================================================
# SETUP AUTOMATION
# =============================================================================

setup_automation() {
    log_section "Setting Up Automation"
    
    # Create backup script
    cat > /opt/bitcoin/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/bitcoin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

tar -czf $BACKUP_DIR/configs_$DATE.tar.gz \
    /opt/bitcoin/configs \
    /opt/bitcoin/docker-compose.yml \
    /opt/bitcoin/scripts \
    /root/setup-config.env 2>/dev/null

find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "Backup completed: $DATE"
EOF

    chmod +x /opt/bitcoin/scripts/backup.sh
    
    # Add cron job
    (crontab -l 2>/dev/null || true; echo "0 3 * * * /opt/bitcoin/scripts/backup.sh > /opt/bitcoin/logs/backup.log 2>&1") | crontab -
    
    log_success "Automation configured"
}

# =============================================================================
# COMPLETION
# =============================================================================

show_next_steps() {
    TAILSCALE_IP=$(cat /opt/bitcoin/.tailscale_ip 2>/dev/null || echo "Not connected")
    
    clear
    echo "=========================================="
    echo "🎉 Bitcoin Node Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Version: $VERSION"
    echo "User: $ADMIN_USER"
    echo "Tailscale: $TAILSCALE_IP"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. Monitor Bitcoin sync (2-5 days):"
    echo "   /opt/bitcoin/scripts/check-sync.sh"
    echo ""
    echo "2. When sync reaches 90%+:"
    echo "   /opt/bitcoin/scripts/enable-all-services.sh"
    echo ""
    echo "3. Check status anytime:"
    echo "   /opt/bitcoin/scripts/status.sh"
    echo ""
    echo "📁 Key Locations:"
    echo "- Config: ~/setup-config.env"
    echo "- Scripts: /opt/bitcoin/scripts/"
    echo "- Data: /opt/bitcoin/data/"
    echo "- Logs: /opt/bitcoin/logs/"
    echo ""
    echo "🔐 Security:"
    echo "- All services accessible via Tailscale only"
    echo "- Firewall configured"
    echo "- Daily backups at 3 AM"
    echo ""
    
    # Save setup info
    cat > /opt/bitcoin/SETUP_INFO.txt << EOF
Bitcoin Node Setup Information
==============================
Date: $(date)
Version: $VERSION
Domain: $DOMAIN_NAME
Admin User: $ADMIN_USER
Tailscale IP: $TAILSCALE_IP

To check sync: /opt/bitcoin/scripts/check-sync.sh
To enable all: /opt/bitcoin/scripts/enable-all-services.sh
To see status: /opt/bitcoin/scripts/status.sh
EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_section "Bitcoin Node Setup v${VERSION}"
    
    # Check configuration
    check_config
    
    # Validate system
    validate_system
    
    # Run setup steps
    initial_setup
    setup_user
    setup_security
    setup_tailscale
    setup_docker
    setup_bitcoin
    setup_automation
    
    # Show completion
    show_next_steps
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi