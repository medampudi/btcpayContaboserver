#!/bin/bash
set -eo pipefail

# =============================================================================
# Bitcoin Node Setup Script for Ubuntu 22.04 - Standard User Version
# Version: 4.0 - Security Best Practices
# =============================================================================
# This script is designed to run as the standard 'ubuntu' user with sudo
# No need for 'sudo su -' or running everything as root
# =============================================================================

VERSION="4.0"
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
    
    # Check if we're running as ubuntu user
    if [[ "$USER" != "ubuntu" ]]; then
        log_warning "This script is designed to run as the 'ubuntu' user"
        log_info "Current user: $USER"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires passwordless sudo access"
        log_info "Run: sudo visudo"
        log_info "Add: ubuntu ALL=(ALL) NOPASSWD:ALL"
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
# INITIAL SETUP (runs with sudo as needed)
# =============================================================================

initial_setup() {
    log_section "Initial System Setup"
    
    # Set hostname and timezone
    sudo hostnamectl set-hostname $SERVER_HOSTNAME
    sudo timedatectl set-timezone $TIMEZONE
    
    # Update system
    log_info "Updating system packages..."
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
    
    # Install essential packages
    log_info "Installing essential packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        curl wget git vim htop ncdu tree \
        ufw fail2ban net-tools dnsutils \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        jq bc moreutils unzip python3-pip
    
    # Configure swap if needed
    if [[ ! -f /swapfile ]]; then
        log_info "Creating ${SWAP_SIZE} swap file..."
        sudo fallocate -l $SWAP_SIZE /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
    fi
    
    log_success "Initial setup complete"
}

# =============================================================================
# SECURITY SETUP
# =============================================================================

setup_security() {
    log_section "Security Configuration"
    
    # Configure SSH
    log_info "Hardening SSH configuration..."
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply secure SSH settings
    sudo tee /etc/ssh/sshd_config.d/99-bitcoin-node.conf > /dev/null << EOF
# Bitcoin Node Security Settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

    # Configure fail2ban
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
maxretry = 3
EOF
    
    sudo systemctl restart fail2ban
    sudo systemctl restart sshd
    
    # Configure firewall
    log_info "Setting up firewall..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Essential ports
    sudo ufw allow $SSH_PORT/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw allow 8333/tcp comment 'Bitcoin'
    sudo ufw allow 9735/tcp comment 'Lightning'
    
    # Allow Tailscale when installed
    sudo ufw allow in on tailscale0 || true
    
    echo "y" | sudo ufw enable
    
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
        sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --accept-routes || true
        sleep 5
        
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [[ -n "$TAILSCALE_IP" ]]; then
            log_success "Tailscale connected: $TAILSCALE_IP"
            mkdir -p ~/.bitcoin
            echo "$TAILSCALE_IP" > ~/.bitcoin/.tailscale_ip
        fi
    else
        log_warning "No Tailscale auth key provided"
        log_info "Run manually: sudo tailscale up"
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
        
        # Add current user to docker group
        sudo usermod -aG docker $USER
        log_warning "You'll need to log out and back in for docker group membership to take effect"
    fi
    
    # Install docker-compose
    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt install -y docker-compose-v2
    fi
    
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker ready"
}

# =============================================================================
# BITCOIN STACK SETUP
# =============================================================================

setup_bitcoin() {
    log_section "Bitcoin Stack Setup"
    
    # Create directory structure in user's home
    BITCOIN_DIR="$HOME/bitcoin-node"
    log_info "Creating Bitcoin directory at $BITCOIN_DIR"
    
    mkdir -p $BITCOIN_DIR/{data,configs,scripts,backups,logs}
    mkdir -p $BITCOIN_DIR/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p $BITCOIN_DIR/mysql
    
    # Create configurations
    create_configs
    
    # Create docker-compose
    create_docker_compose
    
    # Create scripts
    create_scripts
    
    # Create systemd service for better management
    create_systemd_service
    
    # Start Bitcoin Core
    log_info "Starting Bitcoin Core..."
    cd $BITCOIN_DIR
    docker compose up -d bitcoind
    
    log_success "Bitcoin Core started - will take 2-5 days to sync"
    log_info "Monitor with: ~/bitcoin-node/scripts/check-sync.sh"
}

# =============================================================================
# CONFIGURATION FILES
# =============================================================================

create_configs() {
    # Fulcrum config
    cat > $BITCOIN_DIR/configs/fulcrum.conf << EOF
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
    cat > $BITCOIN_DIR/configs/mempool-config.json << EOF
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
    TAILSCALE_IP=$(cat ~/.bitcoin/.tailscale_ip 2>/dev/null || echo "127.0.0.1")
    
    cat > $BITCOIN_DIR/docker-compose.yml << 'EOF'
version: '3.8'

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

  # Additional services use 'profiles' to start later
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
EOF

    # Substitute environment variables
    sed -i "s/\${BITCOIN_RPC_USER}/$BITCOIN_RPC_USER/g" $BITCOIN_DIR/docker-compose.yml
    sed -i "s/\${BITCOIN_RPC_PASS}/$BITCOIN_RPC_PASS/g" $BITCOIN_DIR/docker-compose.yml
    sed -i "s/\${BITCOIN_DBCACHE}/$BITCOIN_DBCACHE/g" $BITCOIN_DIR/docker-compose.yml
    sed -i "s/\${BITCOIN_MAXMEMPOOL}/$BITCOIN_MAXMEMPOOL/g" $BITCOIN_DIR/docker-compose.yml
    sed -i "s/\${BITCOIN_MAX_CONNECTIONS}/$BITCOIN_MAX_CONNECTIONS/g" $BITCOIN_DIR/docker-compose.yml
    sed -i "s/\${TAILSCALE_IP}/$TAILSCALE_IP/g" $BITCOIN_DIR/docker-compose.yml
}

create_scripts() {
    # Check sync script
    cat > $BITCOIN_DIR/scripts/check-sync.sh << 'EOF'
#!/bin/bash
# Check Bitcoin sync status

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get config location
CONFIG_FILE="$HOME/bitcoin-node/setup-config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    CONFIG_FILE="$(dirname $0)/../setup-config.env"
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Config file not found!"
        exit 1
    fi
fi

# Check if running
if ! docker ps | grep -q bitcoind; then
    echo "Bitcoin Core is not running!"
    echo "Start with: cd ~/bitcoin-node && docker compose up -d bitcoind"
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
    echo "Run: ~/bitcoin-node/scripts/enable-all-services.sh"
else
    echo -e "\n⏳ Still syncing... Check again later."
fi
EOF

    # Enable all services script
    cat > $BITCOIN_DIR/scripts/enable-all-services.sh << 'EOF'
#!/bin/bash
# Enable all services after Bitcoin sync

cd ~/bitcoin-node

echo "Starting all services..."
docker compose --profile full up -d

echo ""
echo "All services starting! Wait a few minutes then check:"
echo "~/bitcoin-node/scripts/status.sh"
EOF

    # Status script
    cat > $BITCOIN_DIR/scripts/status.sh << 'EOF'
#!/bin/bash
# Show system status

clear
echo "=== Bitcoin Node Status ==="
echo "=========================="
echo ""
echo "System: $(hostname)"
if [[ -f ~/.bitcoin/.tailscale_ip ]]; then
    echo "Tailscale IP: $(cat ~/.bitcoin/.tailscale_ip)"
fi
echo ""
echo "Services:"
cd ~/bitcoin-node
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|bitcoin|fulcrum|mempool|explorer|postgres"
echo ""
echo "Run ~/bitcoin-node/scripts/check-sync.sh for Bitcoin sync status"
EOF

    chmod +x $BITCOIN_DIR/scripts/*.sh
}

create_systemd_service() {
    # Create systemd service for automatic startup
    sudo tee /etc/systemd/system/bitcoin-node.service > /dev/null << EOF
[Unit]
Description=Bitcoin Node Docker Compose
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$USER
Group=$(id -gn)
WorkingDirectory=$HOME/bitcoin-node
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable bitcoin-node.service
}

# =============================================================================
# SETUP AUTOMATION
# =============================================================================

setup_automation() {
    log_section "Setting Up Automation"
    
    # Create backup script
    cat > $BITCOIN_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/bitcoin-node/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

tar -czf $BACKUP_DIR/configs_$DATE.tar.gz \
    $HOME/bitcoin-node/configs \
    $HOME/bitcoin-node/docker-compose.yml \
    $HOME/bitcoin-node/scripts \
    $HOME/bitcoin-node/setup-config.env 2>/dev/null

find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "Backup completed: $DATE"
EOF

    chmod +x $BITCOIN_DIR/scripts/backup.sh
    
    # Add cron job
    (crontab -l 2>/dev/null || true; echo "0 3 * * * $BITCOIN_DIR/scripts/backup.sh > $BITCOIN_DIR/logs/backup.log 2>&1") | crontab -
    
    log_success "Automation configured"
}

# =============================================================================
# COMPLETION
# =============================================================================

show_next_steps() {
    TAILSCALE_IP=$(cat ~/.bitcoin/.tailscale_ip 2>/dev/null || echo "Not connected")
    
    clear
    echo "=========================================="
    echo "🎉 Bitcoin Node Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Version: $VERSION"
    echo "User: $USER"
    echo "Bitcoin Directory: ~/bitcoin-node"
    echo "Tailscale: $TAILSCALE_IP"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. Monitor Bitcoin sync (2-5 days):"
    echo "   ~/bitcoin-node/scripts/check-sync.sh"
    echo ""
    echo "2. When sync reaches 90%+:"
    echo "   ~/bitcoin-node/scripts/enable-all-services.sh"
    echo ""
    echo "3. Check status anytime:"
    echo "   ~/bitcoin-node/scripts/status.sh"
    echo ""
    echo "📁 Key Locations:"
    echo "- Config: ~/bitcoin-node/setup-config.env"
    echo "- Scripts: ~/bitcoin-node/scripts/"
    echo "- Data: ~/bitcoin-node/data/"
    echo "- Logs: ~/bitcoin-node/logs/"
    echo ""
    echo "🔐 Security:"
    echo "- All services accessible via Tailscale only"
    echo "- No root access required for management"
    echo "- Firewall configured"
    echo "- Daily backups at 3 AM"
    echo ""
    echo "⚠️  IMPORTANT: Log out and back in for docker group access"
    echo ""
    
    # Save setup info
    cat > $BITCOIN_DIR/SETUP_INFO.txt << EOF
Bitcoin Node Setup Information
==============================
Date: $(date)
Version: $VERSION
User: $USER
Domain: $DOMAIN_NAME
Bitcoin Directory: $HOME/bitcoin-node
Tailscale IP: $TAILSCALE_IP

To check sync: ~/bitcoin-node/scripts/check-sync.sh
To enable all: ~/bitcoin-node/scripts/enable-all-services.sh
To see status: ~/bitcoin-node/scripts/status.sh

Security Note: Everything runs as $USER, not root!
EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_section "Bitcoin Node Setup v${VERSION} - Ubuntu User Version"
    
    # Check configuration
    check_config
    
    # Copy config to bitcoin directory if not there
    if [[ ! -f "$HOME/bitcoin-node/setup-config.env" ]]; then
        mkdir -p "$HOME/bitcoin-node"
        cp "$SCRIPT_DIR/setup-config.env" "$HOME/bitcoin-node/setup-config.env"
    fi
    
    # Validate system
    validate_system
    
    # Run setup steps
    initial_setup
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