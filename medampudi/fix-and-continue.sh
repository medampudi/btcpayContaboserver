#!/bin/bash
set -eo pipefail

# Fix and Continue Bitcoin Setup
# This handles the existing admin group issue

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

# Load configuration from setup-config.env if it exists
if [[ -f "setup-config.env" ]]; then
    source setup-config.env
fi

# Set defaults if not loaded
ADMIN_USER="${ADMIN_USER:-rajesh}"
DOMAIN_NAME="${DOMAIN_NAME:-simbotix.com}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.simbotix.com}"
EMAIL="${EMAIL:-medampudi@gmail.com}"
FAMILY_NAME="${FAMILY_NAME:-Medampudi-Family}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-KsVsyjn1Mfu9FA0H}"
POSTGRES_PASS="${POSTGRES_PASS:-YEqgtzxGJeBo392o}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS:-pvq7OVSN1DWrJ1ti}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS:-LRUsrD6nWzJzRpT6}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-tskey-auth-kd3VVUpwui11CNTRL-1MC2UC1YAsP2ab9iPW7asPZBUedJEugR6}"

# Export for subscripts
export BITCOIN_RPC_USER BITCOIN_RPC_PASS BTCPAY_DOMAIN ADMIN_USER EMAIL FAMILY_NAME

log_info "Fixing setup and continuing..."

# Fix admin user issue properly
fix_admin_user() {
    log_info "Handling admin user setup..."
    
    # First check if the user exists
    if id "$ADMIN_USER" &>/dev/null; then
        log_info "User $ADMIN_USER already exists - updating permissions"
        # Make sure user is in sudo group
        usermod -aG sudo $ADMIN_USER || true
        usermod -aG docker $ADMIN_USER || true
    else
        # User doesn't exist, but group might
        if getent group admin &>/dev/null; then
            log_info "Admin group exists - creating user with existing group"
            useradd -m -g admin -s /bin/bash $ADMIN_USER
        else
            log_info "Creating new user and group"
            useradd -m -s /bin/bash $ADMIN_USER
        fi
        
        # Add to sudo group
        usermod -aG sudo $ADMIN_USER
    fi
    
    # Ensure SSH directory exists
    if [[ ! -d /home/$ADMIN_USER/.ssh ]]; then
        mkdir -p /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    fi
    
    log_success "Admin user ready"
}

# Setup Tailscale
setup_tailscale() {
    log_info "Setting up Tailscale..."
    
    # Check if already installed
    if command -v tailscale &> /dev/null; then
        log_info "Tailscale already installed"
        
        # Check if running
        if tailscale status &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
            if [[ -n "$TAILSCALE_IP" ]]; then
                log_success "Tailscale already connected: $TAILSCALE_IP"
                return
            fi
        fi
    else
        # Install Tailscale
        log_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    # Start Tailscale with auth key
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Connecting Tailscale..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --accept-routes
        sleep 5
        
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [[ -n "$TAILSCALE_IP" ]]; then
            log_success "Tailscale connected: $TAILSCALE_IP"
        fi
    else
        log_warning "No Tailscale auth key. Run 'tailscale up' manually"
    fi
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8333/tcp comment 'Bitcoin P2P'
    ufw allow 9735/tcp comment 'Lightning'
    
    # Allow current SSH connection to prevent lockout
    CURRENT_SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        log_info "Allowing SSH from current IP: $CURRENT_SSH_IP"
        ufw allow from $CURRENT_SSH_IP to any port 22 comment 'Current SSH'
    fi
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable firewall
    echo "y" | ufw enable
    
    log_success "Firewall configured"
}

# Install Docker
setup_docker() {
    log_info "Setting up Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        docker --version
    else
        # Install Docker
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    
    # Add admin user to docker group
    usermod -aG docker $ADMIN_USER || true
    
    # Install docker-compose if needed
    if ! docker compose version &> /dev/null; then
        log_info "Installing docker-compose..."
        apt update
        apt install -y docker-compose-v2
    fi
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker ready"
}

# Setup Bitcoin directories
setup_bitcoin_directories() {
    log_info "Creating Bitcoin directories..."
    
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p /opt/bitcoin/mysql
    
    # Set permissions
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    chmod -R 755 /opt/bitcoin
    
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
EOF

    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    
    log_success "Configurations created"
}

# Create monitoring scripts
create_monitoring_scripts() {
    log_info "Creating monitoring scripts..."
    
    # Status script
    cat > /opt/bitcoin/scripts/status.sh << EOF
#!/bin/bash
clear
echo "=== Bitcoin Node Status ==="
echo "=========================="
echo ""
echo "System: \$(hostname)"
echo "Uptime: \$(uptime -p)"
echo ""
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    echo "Tailscale IP: \$(tailscale ip -4)"
fi
echo ""
echo "Docker Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -E "NAME|bitcoin" || echo "No services running"
echo ""
echo "Bitcoin Sync Status:"
if docker ps | grep -q bitcoind; then
    docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo 2>/dev/null | \\
    jq -r '. | "Blocks: \\(.blocks)/\\(.headers) (\\(.verificationprogress * 100 | floor)%)"' 2>/dev/null || echo "Starting up..."
else
    echo "Bitcoin Core not running"
fi
echo ""
echo "Disk Usage:"
df -h /opt/bitcoin | tail -n 1
EOF

    chmod +x /opt/bitcoin/scripts/status.sh
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin/scripts
    
    log_success "Monitoring scripts created"
}

# Start Bitcoin Core
start_bitcoin() {
    log_info "Starting Bitcoin Core..."
    
    cd /opt/bitcoin
    
    # Pull the image first
    docker pull btcpayserver/bitcoin:26.0
    
    # Start Bitcoin
    docker compose up -d bitcoind
    
    # Wait for it to start
    log_info "Waiting for Bitcoin Core to start..."
    sleep 15
    
    # Check if running
    if docker ps | grep -q bitcoind; then
        log_success "Bitcoin Core started successfully"
        
        # Show initial status
        echo ""
        docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo 2>/dev/null | \
        jq -r '. | "Initial Status: \(.blocks) blocks synced"' || echo "Bitcoin Core is initializing..."
    else
        log_warning "Bitcoin Core may still be starting. Check with: docker logs bitcoind"
    fi
}

# Show next steps
show_next_steps() {
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
    
    clear
    echo "=========================================="
    echo "✅ Bitcoin Node Setup Resumed!"
    echo "=========================================="
    echo ""
    echo "Status Summary:"
    echo "✓ Admin user: $ADMIN_USER"
    echo "✓ Tailscale: $TAILSCALE_IP"
    echo "✓ Firewall: Configured"
    echo "✓ Docker: Installed"
    echo "✓ Bitcoin Core: Starting..."
    echo ""
    echo "Monitor Bitcoin sync progress:"
    echo "  cd /opt/bitcoin && ./scripts/status.sh"
    echo ""
    echo "View Bitcoin logs:"
    echo "  docker logs -f bitcoind"
    echo ""
    echo "Check sync percentage:"
    echo "  docker exec bitcoind bitcoin-cli -rpcuser=${BITCOIN_RPC_USER} -rpcpassword=${BITCOIN_RPC_PASS} getblockchaininfo | jq .verificationprogress"
    echo ""
    echo "Bitcoin will sync in 2-5 days. After 90% sync, run:"
    echo "  ./complete-bitcoin-setup.sh"
    echo ""
    echo "Your configuration:"
    echo "  Domain: $DOMAIN_NAME"
    echo "  BTCPay: $BTCPAY_DOMAIN"
    echo "  Data: /opt/bitcoin/data/"
    echo ""
}

# Main execution
main() {
    log_info "Resuming Bitcoin setup..."
    
    # Run each step
    fix_admin_user
    setup_tailscale
    setup_firewall
    setup_docker
    setup_bitcoin_directories
    create_configs
    create_monitoring_scripts
    start_bitcoin
    
    # Show completion
    show_next_steps
}

# Run main
main "$@"