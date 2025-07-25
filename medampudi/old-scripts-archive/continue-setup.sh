#!/bin/bash
set -eo pipefail

# Continue Bitcoin Setup from where it stopped
# This script picks up after system preparation

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

# Load configuration from environment or set defaults
ADMIN_USER="${ADMIN_USER:-admin}"
DOMAIN_NAME="${DOMAIN_NAME:-simbotix.com}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.simbotix.com}"
EMAIL="${EMAIL:-medampudi@gmail.com}"
FAMILY_NAME="${FAMILY_NAME:-Medampudi-Family}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecurePassword}"
POSTGRES_PASS="${POSTGRES_PASS:-PostgresPass}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS:-MariaRootPass}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS:-MempoolPass}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"

# Export for subscripts
export BITCOIN_RPC_USER BITCOIN_RPC_PASS BTCPAY_DOMAIN ADMIN_USER EMAIL FAMILY_NAME

log_info "Continuing Bitcoin setup..."

# Check if we're root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Fix admin user issue
fix_admin_user() {
    log_info "Fixing admin user setup..."
    
    # Check if user exists
    if id "$ADMIN_USER" &>/dev/null; then
        log_info "User $ADMIN_USER already exists"
        # Make sure user is in sudo group
        usermod -aG sudo $ADMIN_USER || true
        
        # Create SSH directory if needed
        if [[ ! -d /home/$ADMIN_USER/.ssh ]]; then
            mkdir -p /home/$ADMIN_USER/.ssh
            chmod 700 /home/$ADMIN_USER/.ssh
            chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
        fi
    else
        # Create user without the group flag
        useradd -m -s /bin/bash $ADMIN_USER
        usermod -aG sudo $ADMIN_USER
        
        # Create SSH directory
        mkdir -p /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    fi
    
    log_success "Admin user ready"
}

# Setup Tailscale
setup_tailscale() {
    log_info "Installing Tailscale..."
    
    # Check if already installed
    if command -v tailscale &> /dev/null; then
        log_info "Tailscale already installed"
    else
        # Install Tailscale
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    # Start Tailscale if auth key provided
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Starting Tailscale with auth key..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh || log_warning "Tailscale may already be running"
    else
        log_warning "No Tailscale auth key. Run 'tailscale up' manually"
    fi
    
    # Get Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$TAILSCALE_IP" ]]; then
        log_success "Tailscale connected: $TAILSCALE_IP"
    fi
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Check if ufw is already configured
    if ufw status | grep -q "Status: active"; then
        log_info "Firewall already active, updating rules..."
    fi
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8333/tcp comment 'Bitcoin P2P'
    ufw allow 9735/tcp comment 'Lightning'
    
    # Allow current SSH connection
    CURRENT_SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        ufw allow from $CURRENT_SSH_IP to any port 22 comment 'Current SSH'
    fi
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

# Install Docker
setup_docker() {
    log_info "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        docker --version
    else
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    
    # Add admin user to docker group
    usermod -aG docker $ADMIN_USER || true
    
    # Install docker-compose if needed
    if ! command -v docker-compose &> /dev/null; then
        apt install -y docker-compose-v2
    fi
    
    # Restart Docker to ensure it's running
    systemctl restart docker
    
    log_success "Docker ready"
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

# Create basic configurations
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
EOF

    # Create basic docker-compose.yml
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
        rpcallowip=172.25.0.0/16
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
    ports:
      - "8333:8333"
EOF

    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    
    log_success "Basic configurations created"
}

# Create monitoring scripts
create_monitoring_scripts() {
    log_info "Creating monitoring scripts..."
    
    # Check if the separate creator exists
    if [[ -f ./create-monitoring-scripts.sh ]]; then
        export BITCOIN_RPC_USER BITCOIN_RPC_PASS BTCPAY_DOMAIN ADMIN_USER EMAIL FAMILY_NAME
        bash ./create-monitoring-scripts.sh
    else
        # Create basic status script
        mkdir -p /opt/bitcoin/scripts
        
        cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
echo "=== Bitcoin Node Status ==="
echo "=========================="
echo ""
echo "System: $(hostname)"
echo "Uptime: $(uptime -p)"
echo ""
echo "Docker Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin"
echo ""
echo "Disk Usage:"
df -h /opt/bitcoin
EOF
        
        chmod +x /opt/bitcoin/scripts/status.sh
    fi
    
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin/scripts
    
    log_success "Monitoring scripts created"
}

# Start initial services
start_services() {
    log_info "Starting Bitcoin Core..."
    
    cd /opt/bitcoin
    
    # Pull image first
    docker pull btcpayserver/bitcoin:26.0
    
    # Start Bitcoin Core
    docker compose up -d bitcoind
    
    # Wait a bit
    sleep 10
    
    # Check if running
    if docker ps | grep -q bitcoind; then
        log_success "Bitcoin Core started"
        echo ""
        echo "To check sync status:"
        echo "docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo"
    else
        log_warning "Bitcoin Core may still be starting..."
    fi
}

# Show next steps
show_next_steps() {
    clear
    echo "=========================================="
    echo "✅ Setup Continued Successfully!"
    echo "=========================================="
    echo ""
    echo "Current Status:"
    if [[ -n "$TAILSCALE_IP" ]]; then
        echo "✓ Tailscale connected: $TAILSCALE_IP"
    else
        echo "- Tailscale: Run 'tailscale up' to connect"
    fi
    echo "✓ Firewall configured"
    echo "✓ Docker installed"
    echo "✓ Bitcoin Core starting..."
    echo ""
    echo "Next Steps:"
    echo "1. Monitor Bitcoin sync:"
    echo "   cd /opt/bitcoin && ./scripts/status.sh"
    echo ""
    echo "2. Check Bitcoin sync progress:"
    echo "   docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo | jq .verificationprogress"
    echo ""
    echo "3. View Bitcoin logs:"
    echo "   docker logs -f bitcoind"
    echo ""
    echo "4. Once Bitcoin is synced (2-5 days), run:"
    echo "   ./complete-bitcoin-setup.sh"
    echo ""
    echo "Important Paths:"
    echo "- Bitcoin data: /opt/bitcoin/data/bitcoin/"
    echo "- Config files: /opt/bitcoin/configs/"
    echo "- Scripts: /opt/bitcoin/scripts/"
    echo ""
}

# Main execution
main() {
    log_info "Continuing Bitcoin setup from admin user creation..."
    
    fix_admin_user
    setup_tailscale
    setup_firewall
    setup_docker
    setup_bitcoin_directories
    create_configs
    create_monitoring_scripts
    start_services
    
    show_next_steps
}

# Run main
main "$@"