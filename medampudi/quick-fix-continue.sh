#!/bin/bash
set -eo pipefail

# Quick fix and continue setup
# Handles the group mismatch issue

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
if [[ -f "setup-config.env" ]]; then
    source setup-config.env
fi

# Set defaults
ADMIN_USER="${ADMIN_USER:-rajesh}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-tskey-auth-kd3VVUpwui11CNTRL-1MC2UC1YAsP2ab9iPW7asPZBUedJEugR6}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-bitcoin_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-KsVsyjn1Mfu9FA0H}"

log_info "Quick fix for user/group issue..."

# First, let's check what exists
log_info "Checking current user/group status..."
echo "Users in admin group:"
getent group admin || echo "No admin group"
echo ""
echo "User rajesh info:"
id rajesh 2>/dev/null || echo "User rajesh doesn't exist"
echo ""

# Fix the ownership issue
fix_ownership() {
    log_info "Fixing ownership..."
    
    # Get the actual group for the user
    if id "$ADMIN_USER" &>/dev/null; then
        USER_GROUP=$(id -gn $ADMIN_USER)
        log_info "User $ADMIN_USER belongs to group: $USER_GROUP"
        
        # Fix SSH directory ownership
        if [[ -d /home/$ADMIN_USER/.ssh ]]; then
            chown -R $ADMIN_USER:$USER_GROUP /home/$ADMIN_USER/.ssh
        else
            mkdir -p /home/$ADMIN_USER/.ssh
            chmod 700 /home/$ADMIN_USER/.ssh
            chown -R $ADMIN_USER:$USER_GROUP /home/$ADMIN_USER/.ssh
        fi
        
        log_success "Ownership fixed"
    else
        log_error "User $ADMIN_USER doesn't exist!"
    fi
}

# Continue with Tailscale
setup_tailscale() {
    log_info "Setting up Tailscale..."
    
    # Check if installed
    if command -v tailscale &> /dev/null; then
        log_info "Tailscale already installed"
        
        # Check if connected
        if tailscale status &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
            if [[ -n "$TAILSCALE_IP" ]]; then
                log_success "Tailscale connected: $TAILSCALE_IP"
                return
            fi
        fi
    else
        # Install Tailscale
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    # Connect with auth key
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Connecting Tailscale..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --accept-routes || log_warning "Tailscale may already be connected"
        sleep 5
        
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [[ -n "$TAILSCALE_IP" ]]; then
            log_success "Tailscale IP: $TAILSCALE_IP"
        fi
    fi
}

# Quick firewall setup
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Get current SSH connection
    CURRENT_SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    
    # Basic firewall rules
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Essential ports
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8333/tcp
    ufw allow 9735/tcp
    
    # Allow current SSH
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        ufw allow from $CURRENT_SSH_IP to any port 22
    fi
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable
    echo "y" | ufw enable
    
    log_success "Firewall configured"
}

# Install Docker if needed
setup_docker() {
    log_info "Checking Docker..."
    
    if command -v docker &> /dev/null; then
        log_success "Docker already installed"
        
        # Add user to docker group
        if id "$ADMIN_USER" &>/dev/null; then
            usermod -aG docker $ADMIN_USER || true
        fi
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        
        # Add user to docker group
        if id "$ADMIN_USER" &>/dev/null; then
            usermod -aG docker $ADMIN_USER
        fi
    fi
    
    # Ensure docker is running
    systemctl start docker
    systemctl enable docker
}

# Create Bitcoin directories
setup_directories() {
    log_info "Creating Bitcoin directories..."
    
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum}
    
    # Set ownership using the correct group
    if id "$ADMIN_USER" &>/dev/null; then
        USER_GROUP=$(id -gn $ADMIN_USER)
        chown -R $ADMIN_USER:$USER_GROUP /opt/bitcoin
    fi
    
    log_success "Directories created"
}

# Create minimal docker-compose
create_docker_compose() {
    log_info "Creating Bitcoin configuration..."
    
    cat > /opt/bitcoin/docker-compose.yml << EOF
version: '3.8'

networks:
  bitcoin:
    driver: bridge

services:
  bitcoind:
    image: btcpayserver/bitcoin:26.0
    container_name: bitcoind
    restart: unless-stopped
    networks:
      - bitcoin
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
        dbcache=4000
    ports:
      - "8333:8333"
      - "127.0.0.1:8332:8332"
EOF

    # Create status script
    cat > /opt/bitcoin/scripts/status.sh << 'EOF'
#!/bin/bash
echo "=== Bitcoin Node Status ==="
echo ""
echo "System: $(hostname)"
if command -v tailscale &> /dev/null; then
    echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
fi
echo ""
echo "Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin"
echo ""
if docker ps | grep -q bitcoind; then
    echo "Bitcoin sync:"
    docker exec bitcoind bitcoin-cli -rpcuser=RPCUSER -rpcpassword=RPCPASS getblockchaininfo 2>/dev/null | \
    jq -r '. | "Blocks: \(.blocks)/\(.headers) (\(.verificationprogress * 100 | floor)%)"' || echo "Initializing..."
fi
EOF

    # Replace credentials in status script
    sed -i "s/RPCUSER/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/status.sh
    sed -i "s/RPCPASS/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/status.sh
    
    chmod +x /opt/bitcoin/scripts/status.sh
    
    # Fix ownership
    if id "$ADMIN_USER" &>/dev/null; then
        USER_GROUP=$(id -gn $ADMIN_USER)
        chown -R $ADMIN_USER:$USER_GROUP /opt/bitcoin
    fi
}

# Start Bitcoin
start_bitcoin() {
    log_info "Starting Bitcoin Core..."
    
    cd /opt/bitcoin
    
    # Pull image
    docker pull btcpayserver/bitcoin:26.0
    
    # Start
    docker compose up -d bitcoind
    
    sleep 10
    
    if docker ps | grep -q bitcoind; then
        log_success "Bitcoin Core started!"
    else
        log_warning "Check logs with: docker logs bitcoind"
    fi
}

# Main
main() {
    log_info "Starting quick fix and continue..."
    
    fix_ownership
    setup_tailscale
    setup_firewall
    setup_docker
    setup_directories
    create_docker_compose
    start_bitcoin
    
    # Summary
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
    
    echo ""
    echo "=========================================="
    echo "✅ Setup Continued!"
    echo "=========================================="
    echo ""
    echo "Status:"
    echo "- User: $ADMIN_USER (group: $(id -gn $ADMIN_USER 2>/dev/null || echo 'N/A'))"
    echo "- Tailscale: $TAILSCALE_IP"
    echo "- Bitcoin: Starting (check with: docker logs bitcoind)"
    echo ""
    echo "Next steps:"
    echo "1. Monitor sync: cd /opt/bitcoin && ./scripts/status.sh"
    echo "2. Watch logs: docker logs -f bitcoind"
    echo "3. After sync: ./complete-bitcoin-setup.sh"
    echo ""
}

main "$@"