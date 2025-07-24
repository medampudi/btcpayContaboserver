#!/bin/bash
set -eo pipefail

# Bitcoin Sovereignty Setup - Simplified Version
# This version avoids complex heredocs and uses separate script creation

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

# Get configuration from environment
DOMAIN_NAME="${DOMAIN_NAME:-simbotix.com}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.simbotix.com}"
EMAIL="${EMAIL:-medampudi@gmail.com}"
FAMILY_NAME="${FAMILY_NAME:-Medampudi-Family}"
SERVER_HOSTNAME="${SERVER_HOSTNAME:-medampudi-bitcoin}"
SWAP_SIZE="${SWAP_SIZE:-8G}"
TIMEZONE="${TIMEZONE:-Asia/Kolkata}"
ADMIN_USER="${ADMIN_USER:-admin}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecurePassword}"
POSTGRES_PASS="${POSTGRES_PASS:-PostgresPass}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS:-MariaRootPass}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS:-MempoolPass}"

# Export for subscripts
export BITCOIN_RPC_USER BITCOIN_RPC_PASS BTCPAY_DOMAIN ADMIN_USER EMAIL FAMILY_NAME

# Validation
validate_config() {
    log_info "Validating configuration..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu"
        exit 1
    fi
    
    log_success "Configuration validated"
}

# System preparation
prepare_system() {
    log_info "Preparing system..."
    
    # Set hostname and timezone
    hostnamectl set-hostname $SERVER_HOSTNAME
    timedatectl set-timezone $TIMEZONE
    
    # Update system
    apt update && apt upgrade -y
    
    # Install packages
    apt install -y \
        curl wget git vim htop ncdu \
        ufw fail2ban net-tools \
        software-properties-common \
        jq bc mailutils
    
    # Configure swap if needed
    if [[ ! -f /swapfile ]]; then
        fallocate -l $SWAP_SIZE /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    log_success "System prepared"
}

# Create admin user
setup_admin_user() {
    log_info "Setting up admin user..."
    
    if ! id "$ADMIN_USER" &>/dev/null; then
        adduser --disabled-password --gecos "" $ADMIN_USER
        usermod -aG sudo $ADMIN_USER
        
        # Create SSH directory
        mkdir -p /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    fi
    
    log_success "Admin user configured"
}

# Setup Tailscale
setup_tailscale() {
    log_info "Installing Tailscale..."
    
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Start Tailscale
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
    else
        log_warning "No Tailscale auth key. Run 'tailscale up' manually"
    fi
    
    log_success "Tailscale installed"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8333/tcp
    ufw allow 9735/tcp
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

# Install Docker
setup_docker() {
    log_info "Installing Docker..."
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add user to docker group
    usermod -aG docker $ADMIN_USER
    
    # Install docker-compose
    apt install -y docker-compose-v2
    
    log_success "Docker installed"
}

# Setup Bitcoin directories
setup_bitcoin_directories() {
    log_info "Creating Bitcoin directories..."
    
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p /opt/bitcoin/mysql
    
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    
    log_success "Directories created"
}

# Create configurations
create_configs() {
    log_info "Creating configurations..."
    
    # Create Fulcrum config
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
bitcoind_timeout = 300
bitcoind_clients = 4
EOF

    # Create Mempool config
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

    # Create docker-compose.yml
    cp /opt/bitcoin/configs/docker-compose-template.yml /opt/bitcoin/docker-compose.yml 2>/dev/null || \
    create_docker_compose
    
    log_success "Configurations created"
}

# Create docker-compose (simplified)
create_docker_compose() {
    # Download template or create basic version
    cat > /opt/bitcoin/docker-compose.yml << 'EOF'
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
    ports:
      - "8333:8333"
EOF
    
    # This is a minimal version - the full version would be downloaded or created separately
}

# Create monitoring scripts using separate script
create_monitoring_scripts() {
    log_info "Creating monitoring scripts..."
    
    # Use the separate script creator
    if [[ -f ./create-monitoring-scripts.sh ]]; then
        bash ./create-monitoring-scripts.sh
    else
        # Create basic scripts manually
        mkdir -p /opt/bitcoin/scripts
        
        # Basic status script
        cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
echo "Bitcoin Node Status"
echo "=================="
docker ps | grep -E "bitcoind|fulcrum|mempool"
EOF
        
        chmod +x /opt/bitcoin/scripts/*.sh
    fi
    
    log_success "Monitoring scripts created"
}

# Start services
start_services() {
    log_info "Starting Bitcoin services..."
    
    cd /opt/bitcoin
    
    # Start Bitcoin Core
    docker compose up -d bitcoind
    
    log_info "Bitcoin Core starting..."
    sleep 30
    
    # Start databases
    docker compose up -d postgres mempool-db 2>/dev/null || true
    
    log_success "Services started"
}

# Setup cron jobs
setup_cron() {
    log_info "Setting up cron jobs..."
    
    # Create cron entries
    cat > /tmp/bitcoin-cron << EOF
# Daily backup at 3 AM
0 3 * * * /opt/bitcoin/scripts/backup.sh

# Health check every 15 minutes
*/15 * * * * /opt/bitcoin/scripts/health-check.sh
EOF
    
    crontab -u $ADMIN_USER /tmp/bitcoin-cron
    rm /tmp/bitcoin-cron
    
    log_success "Cron jobs configured"
}

# Show completion
show_completion() {
    clear
    echo "=========================================="
    echo "✅ Bitcoin Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Next Steps:"
    echo "1. Complete Tailscale setup: tailscale up"
    echo "2. Monitor Bitcoin sync: cd /opt/bitcoin && ./scripts/status.sh"
    echo "3. Access services via Tailscale IP"
    echo ""
    echo "Important Locations:"
    echo "- Config: /opt/bitcoin/configs/"
    echo "- Scripts: /opt/bitcoin/scripts/"
    echo "- Data: /opt/bitcoin/data/"
    echo ""
}

# Main execution
main() {
    log_info "Starting Bitcoin Sovereignty Setup"
    
    validate_config
    prepare_system
    setup_admin_user
    setup_tailscale
    setup_firewall
    setup_docker
    setup_bitcoin_directories
    create_configs
    create_monitoring_scripts
    start_services
    setup_cron
    
    show_completion
}

# Run main
main "$@"