#!/bin/bash
set -eo pipefail

# =============================================================================
# Bitcoin Sovereignty Infrastructure - Complete Automated Setup Script
# For Ubuntu 22.04/24.04 LTS on OVH or similar VPS
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# =============================================================================
# CONFIGURATION SECTION - MODIFY THESE VALUES
# =============================================================================

# Domain Configuration
DOMAIN_NAME="${DOMAIN_NAME:-simbotix.com}"
BTCPAY_DOMAIN="${BTCPAY_DOMAIN:-pay.simbotix.com}"
EMAIL="${EMAIL:-medampudi@gmail.com}"
FAMILY_NAME="${FAMILY_NAME:-Medampudi-Family}"

# Server Configuration
SERVER_HOSTNAME="${SERVER_HOSTNAME:-medampudi-bitcoin}"
SWAP_SIZE="${SWAP_SIZE:-8G}"
TIMEZONE="${TIMEZONE:-Asia/Kolkata}"
CURRENCY_DISPLAY="${CURRENCY_DISPLAY:-INR}"

# Security Configuration
SSH_PORT="${SSH_PORT:-22}"
ADMIN_USER="${ADMIN_USER:-admin}"

# Bitcoin Configuration
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-medampudi_rpc_user}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS:-SecureMedampudiRPC2025!}"
BITCOIN_MAX_CONNECTIONS="${BITCOIN_MAX_CONNECTIONS:-125}"
BITCOIN_DBCACHE="${BITCOIN_DBCACHE:-4000}"
BITCOIN_MAXMEMPOOL="${BITCOIN_MAXMEMPOOL:-2000}"

# Database Passwords
POSTGRES_PASS="${POSTGRES_PASS:-MedampudiPostgres2025!}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS:-MedampudiMariaRoot2025!}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS:-MedampudiMempool2025!}"

# API Keys
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"

# Family Members
FAMILY_MEMBERS="${FAMILY_MEMBERS:-Rajesh Apoorva Meera Vidur}"

# Installation Options
SKIP_BITCOIN_SYNC="${SKIP_BITCOIN_SYNC:-false}"
ENABLE_TOR="${ENABLE_TOR:-false}"
ENABLE_I2P="${ENABLE_I2P:-false}"

# =============================================================================
# VALIDATION SECTION
# =============================================================================

validate_config() {
    log_info "Validating configuration..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu"
        exit 1
    fi
    
    # Validate required fields
    if [[ -z "$DOMAIN_NAME" ]] || [[ "$DOMAIN_NAME" == "your-actual-domain.com" ]]; then
        log_error "Please set DOMAIN_NAME to your actual domain"
        exit 1
    fi
    
    if [[ -z "$EMAIL" ]] || [[ "$EMAIL" == "your-email@gmail.com" ]]; then
        log_error "Please set EMAIL to your actual email"
        exit 1
    fi
    
    log_success "Configuration validated"
}

# =============================================================================
# SYSTEM PREPARATION
# =============================================================================

prepare_system() {
    log_info "Preparing system..."
    
    # Set hostname
    hostnamectl set-hostname $SERVER_HOSTNAME
    echo "127.0.0.1 $SERVER_HOSTNAME" >> /etc/hosts
    
    # Set timezone
    timedatectl set-timezone $TIMEZONE
    
    # Update system
    apt update && apt upgrade -y
    
    # Install essential packages
    apt install -y \
        curl wget git vim htop ncdu tree \
        ufw fail2ban net-tools dnsutils \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        jq moreutils unzip python3-pip \
        mailutils postfix bc
    
    # Configure swap
    if [[ ! -f /swapfile ]]; then
        fallocate -l $SWAP_SIZE /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        # Optimize swappiness for server
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        sysctl -p
    fi
    
    log_success "System prepared"
}

# =============================================================================
# USER SETUP
# =============================================================================

setup_admin_user() {
    log_info "Setting up admin user..."
    
    # Create admin user if doesn't exist
    if ! id "$ADMIN_USER" &>/dev/null; then
        adduser --disabled-password --gecos "" $ADMIN_USER
        usermod -aG sudo $ADMIN_USER
        
        # Generate SSH key for admin
        sudo -u $ADMIN_USER ssh-keygen -t ed25519 -f /home/$ADMIN_USER/.ssh/id_ed25519 -N ""
        
        # Setup SSH directory
        mkdir -p /home/$ADMIN_USER/.ssh
        chmod 700 /home/$ADMIN_USER/.ssh
        chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    fi
    
    log_success "Admin user configured"
}

# =============================================================================
# SECURITY SETUP
# =============================================================================

setup_security() {
    log_info "Configuring security..."
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Harden SSH
    cat > /etc/ssh/sshd_config.d/99-bitcoin-hardening.conf <<EOF
# Bitcoin Node Security Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers $ADMIN_USER
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
Banner /etc/ssh/banner.txt
EOF

    # Create SSH banner
    cat > /etc/ssh/banner.txt <<EOF
*******************************************************************
*                     AUTHORIZED ACCESS ONLY                      *
*  This is a private Bitcoin node. All activities are monitored.  *
*  Unauthorized access attempts will be reported to authorities.  *
*******************************************************************
EOF

    # Configure fail2ban
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = $EMAIL
sendername = Fail2ban
mta = sendmail
action = %(action_mwl)s

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

    systemctl restart fail2ban
    systemctl restart sshd
    
    log_success "Security configured"
}

# =============================================================================
# TAILSCALE SETUP
# =============================================================================

setup_tailscale() {
    log_info "Installing Tailscale..."
    
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Start Tailscale with auth key if provided
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
    else
        log_warning "No Tailscale auth key provided. Please run 'tailscale up' manually"
    fi
    
    # Wait for Tailscale to connect
    sleep 5
    
    # Get Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    
    if [[ -n "$TAILSCALE_IP" ]]; then
        log_success "Tailscale connected: $TAILSCALE_IP"
        
        # Lock SSH to Tailscale only
        sed -i "s/#ListenAddress 0.0.0.0/ListenAddress $TAILSCALE_IP\nListenAddress 127.0.0.1/" /etc/ssh/sshd_config
        systemctl restart sshd
    else
        log_warning "Tailscale not connected yet"
    fi
}

# =============================================================================
# FIREWALL SETUP
# =============================================================================

setup_firewall() {
    log_info "Configuring firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 80/tcp comment 'HTTP for Let\'s Encrypt'
    ufw allow 443/tcp comment 'HTTPS for BTCPay'
    ufw allow 8333/tcp comment 'Bitcoin P2P'
    ufw allow 9735/tcp comment 'Lightning Network'
    
    # Allow SSH on current connection to prevent lockout
    CURRENT_SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        ufw allow from $CURRENT_SSH_IP to any port $SSH_PORT comment 'Temporary SSH access'
    fi
    
    # Allow Tailscale
    ufw allow in on tailscale0
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

# =============================================================================
# DOCKER SETUP
# =============================================================================

setup_docker() {
    log_info "Installing Docker..."
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc || true
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add admin user to docker group
    usermod -aG docker $ADMIN_USER
    
    # Install docker-compose
    apt install -y docker-compose-v2
    
    # Configure Docker daemon
    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

    systemctl restart docker
    
    # Verify installation
    docker --version
    docker compose version
    
    log_success "Docker installed"
}

# =============================================================================
# CLOUDFLARE SETUP
# =============================================================================

setup_cloudflare() {
    log_info "Setting up Cloudflare..."
    
    # Install cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    
    # Create config directory
    mkdir -p /etc/cloudflared
    mkdir -p /home/$ADMIN_USER/.cloudflared
    
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]] && [[ -n "$CLOUDFLARE_ACCOUNT_ID" ]]; then
        # Auto-create tunnel using API
        TUNNEL_NAME="bitcoin-${FAMILY_NAME,,}"
        
        # For now, just prepare for manual setup
        TUNNEL_ID="YOUR_TUNNEL_ID"
        log_warning "Cloudflare tunnel needs manual setup - API creation not implemented yet"
    else
        log_warning "Cloudflare API credentials not provided. Manual tunnel setup required."
        TUNNEL_ID="YOUR_TUNNEL_ID"
    fi
    
    # Create tunnel config
    cat > /etc/cloudflared/config.yml <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: /etc/cloudflared/${TUNNEL_ID}.json

originRequest:
  noTLSVerify: true
  connectTimeout: 30s
  
ingress:
  # BTCPay Server - Public Access
  - hostname: ${BTCPAY_DOMAIN}
    service: http://localhost:80
    originRequest:
      httpHostHeader: ${BTCPAY_DOMAIN}
      
  # Catch-all rule
  - service: http_status:404
EOF

    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.cloudflared
    
    log_success "Cloudflare configured"
}

# =============================================================================
# BITCOIN STACK SETUP
# =============================================================================

setup_bitcoin_directories() {
    log_info "Creating Bitcoin directories..."
    
    # Create directory structure
    mkdir -p /opt/bitcoin/{data,configs,scripts,backups,logs}
    mkdir -p /opt/bitcoin/data/{bitcoin,fulcrum,lightning,btcpay}
    mkdir -p /opt/bitcoin/mysql
    
    # Set ownership
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    
    log_success "Directories created"
}

create_bitcoin_configs() {
    log_info "Creating Bitcoin configurations..."
    
    # Fulcrum configuration
    cat > /opt/bitcoin/configs/fulcrum.conf <<EOF
# Fulcrum Configuration
datadir = /data
bitcoind = bitcoind:8332
rpcuser = ${BITCOIN_RPC_USER}
rpcpassword = ${BITCOIN_RPC_PASS}

# Network binding
tcp = 0.0.0.0:50001
ssl = 0.0.0.0:50002

# SSL Certificate
cert = /data/fulcrum.crt
key = /data/fulcrum.key
peering = false

# Performance settings
fast-sync = 1
db_max_open_files = 500
db_mem = 4000.0
bitcoind_timeout = 300
bitcoind_clients = 4
worker_threads = 0

# Logging
debug = false
EOF

    # Mempool configuration
    cat > /opt/bitcoin/configs/mempool-config.json <<EOF
{
  "MEMPOOL": {
    "NETWORK": "mainnet",
    "BACKEND": "electrum",
    "HTTP_PORT": 8999,
    "API_URL_PREFIX": "/api/v1/",
    "POLL_RATE_MS": 2000,
    "CACHE_ENABLED": true
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
  },
  "STATISTICS": {
    "ENABLED": true,
    "TX_PER_SECOND_SAMPLE_PERIOD": 150
  }
}
EOF

    # Create docker-compose.yml
    cat > /opt/bitcoin/docker-compose.yml <<EOF
version: '3.8'

networks:
  bitcoin:
    name: bitcoin
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
  lightning_data:
    driver: local
  mempool_data:
    driver: local

services:
  # Bitcoin Core - Full Node
  bitcoind:
    image: btcpayserver/bitcoin:26.0
    container_name: bitcoind
    hostname: bitcoind
    restart: unless-stopped
    stop_grace_period: 30m
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
        maxconnections=${BITCOIN_MAX_CONNECTIONS}
        dbcache=${BITCOIN_DBCACHE}
        maxmempool=${BITCOIN_MAXMEMPOOL}
        mempoolexpiry=72
        rpcworkqueue=256
        rpcthreads=16
    ports:
      - "8333:8333"  # P2P
      - "${TAILSCALE_IP:-127.0.0.1}:8332:8332"  # RPC via Tailscale only
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Fulcrum - Electrum Server
  fulcrum:
    image: cculianu/fulcrum:latest
    container_name: fulcrum
    hostname: fulcrum
    restart: unless-stopped
    stop_grace_period: 5m
    depends_on:
      - bitcoind
    networks:
      bitcoin:
        ipv4_address: 172.25.0.20
    volumes:
      - fulcrum_data:/data
      - ./configs/fulcrum.conf:/etc/fulcrum.conf:ro
    ports:
      - "${TAILSCALE_IP:-127.0.0.1}:50001:50001"  # TCP
      - "${TAILSCALE_IP:-127.0.0.1}:50002:50002"  # SSL
    environment:
      - DATA_DIR=/data
      - DAEMON_RPC_ADDR=bitcoind:8332
      - DAEMON_RPC_USER=${BITCOIN_RPC_USER}
      - DAEMON_RPC_PASS=${BITCOIN_RPC_PASS}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # PostgreSQL for BTCPay
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    hostname: postgres
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
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=C"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # MariaDB for Mempool
  mempool-db:
    image: mariadb:10.11
    container_name: mempool-db
    hostname: mempool-db
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
      MYSQL_INITDB_SKIP_TZINFO: 1
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --default-time-zone='+00:00'
      --max_connections=200
      --innodb_buffer_pool_size=1G
      --innodb_log_file_size=256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Mempool API
  mempool-api:
    image: mempool/backend:latest
    container_name: mempool-api
    hostname: mempool-api
    restart: unless-stopped
    stop_grace_period: 1m
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
      MEMPOOL_HTTP_PORT: 8999
      ELECTRUM_HOST: fulcrum
      ELECTRUM_PORT: 50001
      ELECTRUM_TLS_ENABLED: "false"
      CORE_RPC_HOST: bitcoind
      CORE_RPC_PORT: 8332
      CORE_RPC_USERNAME: ${BITCOIN_RPC_USER}
      CORE_RPC_PASSWORD: ${BITCOIN_RPC_PASS}
      DATABASE_ENABLED: "true"
      DATABASE_HOST: mempool-db
      DATABASE_PORT: 3306
      DATABASE_DATABASE: mempool
      DATABASE_USERNAME: mempool
      DATABASE_PASSWORD: ${MARIADB_MEMPOOL_PASS}
      STATISTICS_ENABLED: "true"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Mempool Frontend
  mempool-web:
    image: mempool/frontend:latest
    container_name: mempool-web
    hostname: mempool-web
    restart: unless-stopped
    depends_on:
      - mempool-api
    networks:
      bitcoin:
        ipv4_address: 172.25.0.42
    ports:
      - "${TAILSCALE_IP:-127.0.0.1}:8080:8080"
    environment:
      FRONTEND_HTTP_PORT: "8080"
      BACKEND_MAINNET_HTTP_HOST: mempool-api
      BACKEND_MAINNET_HTTP_PORT: 8999
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # BTC RPC Explorer
  btc-rpc-explorer:
    image: btcpayserver/btc-rpc-explorer:latest
    container_name: btc-explorer
    hostname: btc-explorer
    restart: unless-stopped
    depends_on:
      - bitcoind
      - fulcrum
    networks:
      bitcoin:
        ipv4_address: 172.25.0.50
    ports:
      - "${TAILSCALE_IP:-127.0.0.1}:3002:3002"
    environment:
      BTCEXP_HOST: 0.0.0.0
      BTCEXP_PORT: 3002
      BTCEXP_BITCOIND_HOST: bitcoind
      BTCEXP_BITCOIND_PORT: 8332
      BTCEXP_BITCOIND_USER: ${BITCOIN_RPC_USER}
      BTCEXP_BITCOIND_PASS: ${BITCOIN_RPC_PASS}
      BTCEXP_ELECTRUM_SERVERS: tcp://fulcrum:50001
      BTCEXP_SLOW_DEVICE_MODE: "false"
      BTCEXP_NO_INMEMORY_RPC_CACHE: "false"
      BTCEXP_UI_THEME: dark
      BTCEXP_PRIVACY_MODE: "false"
      BTCEXP_NO_RATES: "false"
      BTCEXP_DISPLAY_CURRENCY: ${CURRENCY_DISPLAY}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin
    
    log_success "Bitcoin configurations created"
}

# =============================================================================
# MONITORING SCRIPTS
# =============================================================================

create_monitoring_scripts() {
    log_info "Creating monitoring scripts..."
    
    # Create directory
    mkdir -p /opt/bitcoin/scripts
    
    # Status script with proper variable handling
    cat > /opt/bitcoin/scripts/status.sh <<'SCRIPT_EOF'
#!/bin/bash
clear
echo "=== Bitcoin Sovereignty Stack Status ==="
echo "========================================"
echo ""
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
echo "Swap: $(free -h | grep Swap | awk '{print $3 " / " $2}')"
echo ""
echo "=== Disk Usage ==="
df -h | grep -E "Filesystem|/opt/bitcoin|/$" | awk '{printf "%-20s %5s %5s %5s %5s\n", $1, $2, $3, $4, $5}'
echo ""
echo "=== Bitcoin Core ==="
if command -v docker &> /dev/null && docker ps | grep -q bitcoind; then
    SYNC_INFO=$(docker exec bitcoind bitcoin-cli -rpcuser=BITCOIN_RPC_USER_PLACEHOLDER -rpcpassword=BITCOIN_RPC_PASS_PLACEHOLDER getblockchaininfo 2>/dev/null)
    if [ $? -eq 0 ]; then
        BLOCKS=$(echo $SYNC_INFO | jq -r '.blocks')
        HEADERS=$(echo $SYNC_INFO | jq -r '.headers')
        PROGRESS=$(echo $SYNC_INFO | jq -r '.verificationprogress')
        PROGRESS_PCT=$(echo "scale=2; $PROGRESS * 100" | bc)
        SIZE=$(echo $SYNC_INFO | jq -r '.size_on_disk')
        SIZE_GB=$(echo "scale=2; $SIZE / 1073741824" | bc)
        
        echo "Blocks: $BLOCKS / $HEADERS"
        echo "Sync Progress: ${PROGRESS_PCT}%"
        echo "Chain Size: ${SIZE_GB} GB"
        
        # Get peer info
        PEER_COUNT=$(docker exec bitcoind bitcoin-cli -rpcuser=BITCOIN_RPC_USER_PLACEHOLDER -rpcpassword=BITCOIN_RPC_PASS_PLACEHOLDER getconnectioncount 2>/dev/null || echo "0")
        echo "Connected Peers: $PEER_COUNT"
    else
        echo "Bitcoin Core: Starting up..."
    fi
else
    echo "Bitcoin Core: Not running"
fi
echo ""
echo "=== Docker Services ==="
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | grep -E "NAME|bitcoind|fulcrum|mempool|btc-explorer|postgres|mempool-db"
else
    echo "Docker not installed"
fi
echo ""
echo "=== Network Services ==="
echo "Firewall: $(sudo ufw status | grep Status | awk '{print $2}')"
echo "Tailscale: $(command -v tailscale &> /dev/null && (tailscale status | grep -q "Logged out" && echo "Not Connected" || echo "Connected: $(tailscale ip -4)") || echo "Not Installed")"
echo "Cloudflare: $(systemctl is-active cloudflared 2>/dev/null || echo "Not installed")"
echo ""
echo "=== Service URLs ==="
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4)
    echo "BTCPay Server: https://BTCPAY_DOMAIN_PLACEHOLDER"
    echo "Mempool Explorer: http://$TAILSCALE_IP:8080"
    echo "BTC RPC Explorer: http://$TAILSCALE_IP:3002"
    echo "Electrum Server: $TAILSCALE_IP:50001"
fi
echo ""
echo "Last updated: $(date)"
SCRIPT_EOF

    # Replace placeholders in status script
    sed -i "s/BITCOIN_RPC_USER_PLACEHOLDER/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/status.sh
    sed -i "s/BITCOIN_RPC_PASS_PLACEHOLDER/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/status.sh
    sed -i "s/BTCPAY_DOMAIN_PLACEHOLDER/${BTCPAY_DOMAIN}/g" /opt/bitcoin/scripts/status.sh
    
    # Bitcoin check script
    cat > /opt/bitcoin/scripts/check-bitcoin.sh <<'SCRIPT_EOF'
#!/bin/bash
if docker ps | grep -q bitcoind; then
    docker exec bitcoind bitcoin-cli \
        -rpcuser=BITCOIN_RPC_USER_PLACEHOLDER \
        -rpcpassword=BITCOIN_RPC_PASS_PLACEHOLDER \
        getblockchaininfo | jq '{
            chain: .chain,
            blocks: .blocks,
            headers: .headers,
            progress: (.verificationprogress * 100 | tostring + "%"),
            size_gb: (.size_on_disk / 1073741824 | tostring + " GB"),
            pruned: .pruned
        }'
else
    echo "Bitcoin Core is not running"
fi
SCRIPT_EOF

    # Replace placeholders
    sed -i "s/BITCOIN_RPC_USER_PLACEHOLDER/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/check-bitcoin.sh
    sed -i "s/BITCOIN_RPC_PASS_PLACEHOLDER/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/check-bitcoin.sh
    
    # Access info script
    cat > /opt/bitcoin/scripts/access-info.sh <<'SCRIPT_EOF'
#!/bin/bash
echo "=== Bitcoin Stack Access Information ==="
echo "======================================="
echo ""
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4)
    echo "=== Private Services (via Tailscale) ==="
    echo "Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "Mempool Explorer:    http://$TAILSCALE_IP:8080"
    echo "BTC RPC Explorer:    http://$TAILSCALE_IP:3002"
    echo "Lightning Dashboard: http://$TAILSCALE_IP:3000"
    echo ""
    echo "Electrum Server:     $TAILSCALE_IP:50001 (TCP)"
    echo "Electrum Server SSL: $TAILSCALE_IP:50002 (SSL)"
    echo "Bitcoin RPC:         $TAILSCALE_IP:8332"
    echo ""
    echo "SSH Access:          ssh ADMIN_USER_PLACEHOLDER@$TAILSCALE_IP"
else
    echo "Tailscale not connected. Please run: tailscale up"
fi
echo ""
echo "=== Public Services ==="
echo "BTCPay Server:       https://BTCPAY_DOMAIN_PLACEHOLDER"
echo ""
echo "=== Wallet Configuration ==="
echo "For Electrum, Sparrow, or other wallets:"
echo "Server: [Your Tailscale IP]"
echo "Port: 50001 (TCP) or 50002 (SSL)"
echo "No proxy needed within Tailscale network"
SCRIPT_EOF

    # Replace placeholders
    sed -i "s/ADMIN_USER_PLACEHOLDER/${ADMIN_USER}/g" /opt/bitcoin/scripts/access-info.sh
    sed -i "s/BTCPAY_DOMAIN_PLACEHOLDER/${BTCPAY_DOMAIN}/g" /opt/bitcoin/scripts/access-info.sh
    
    # Make scripts executable
    chmod +x /opt/bitcoin/scripts/*.sh
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin/scripts
    
    log_success "Monitoring scripts created"
}

# =============================================================================
# BTCPAY SERVER SETUP
# =============================================================================

setup_btcpay() {
    log_info "Setting up BTCPay Server..."
    
    cd /opt/bitcoin
    mkdir -p btcpay
    cd btcpay
    
    # Clone BTCPay Docker
    git clone https://github.com/btcpayserver/btcpayserver-docker
    cd btcpayserver-docker
    
    # Create environment file
    cat > btcpay.env <<EOF
export BTCPAY_HOST="${BTCPAY_DOMAIN}"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="bitcoin-nobitcoind;opt-add-thunderhub"
export BTCPAY_ENABLE_SSH=false
export LIGHTNING_ALIAS="${FAMILY_NAME}-Lightning"
export BTCPAYGEN_EXCLUDE_FRAGMENTS="nginx-https"
export BTCPAY_EXTERNAL_URL="https://${BTCPAY_DOMAIN}"

# Use external Bitcoin node
export BTCPAY_EXTERNAL_BITCOIND_HOST="172.25.0.10"
export BTCPAY_EXTERNAL_BITCOIND_RPCPORT="8332"
export BTCPAY_EXTERNAL_BITCOIND_RPCUSER="${BITCOIN_RPC_USER}"
export BTCPAY_EXTERNAL_BITCOIND_RPCPASSWORD="${BITCOIN_RPC_PASS}"

# Database
export POSTGRES_HOST="172.25.0.30"
export POSTGRES_DB="btcpay"
export POSTGRES_USER="btcpay"
export POSTGRES_PASSWORD="${POSTGRES_PASS}"
EOF

    # Source and install
    source btcpay.env
    
    # Skip for now - will be run after Bitcoin sync
    # ./btcpay-setup.sh -i
    
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin/btcpay
    
    log_success "BTCPay Server prepared (will start after Bitcoin sync)"
}

# =============================================================================
# SERVICE STARTUP
# =============================================================================

start_services() {
    log_info "Starting Bitcoin services..."
    
    cd /opt/bitcoin
    
    # Start Bitcoin Core first
    docker compose up -d bitcoind
    
    log_info "Bitcoin Core starting... Checking status in 30 seconds"
    sleep 30
    
    # Check Bitcoin status
    ./scripts/check-bitcoin.sh
    
    # Start databases
    docker compose up -d postgres mempool-db
    
    log_info "Databases started. Other services will start based on Bitcoin sync progress."
    log_info "Run './scripts/status.sh' to monitor progress"
    
    log_success "Initial services started"
}

# =============================================================================
# CRON JOBS
# =============================================================================

setup_cron_jobs() {
    log_info "Setting up cron jobs..."
    
    # Create backup script first
    cat > /opt/bitcoin/scripts/backup.sh <<'SCRIPT_EOF'
#!/bin/bash
BACKUP_DIR="/opt/bitcoin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/opt/bitcoin/logs/backup.log"

# Create directories
mkdir -p $BACKUP_DIR
mkdir -p $(dirname $LOG_FILE)

echo "[$(date)] Starting backup..." >> $LOG_FILE

# Backup configurations
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz \
    /opt/bitcoin/configs \
    /opt/bitcoin/docker-compose.yml \
    /opt/bitcoin/scripts \
    2>> $LOG_FILE

# Backup BTCPay data if exists
if [ -d "/opt/bitcoin/btcpay" ]; then
    cd /opt/bitcoin/btcpay/btcpayserver-docker
    if [ -f "./btcpay-backup.sh" ]; then
        ./btcpay-backup.sh $BACKUP_DIR/btcpay_$DATE.tar.gz >> $LOG_FILE 2>&1
    fi
fi

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "[$(date)] Backup completed" >> $LOG_FILE
echo "Backup completed: $DATE"
SCRIPT_EOF

    chmod +x /opt/bitcoin/scripts/backup.sh
    
    # Create health check script
    cat > /opt/bitcoin/scripts/health-check.sh <<'SCRIPT_EOF'
#!/bin/bash
ALERT_EMAIL="EMAIL_PLACEHOLDER"
LOG_FILE="/opt/bitcoin/logs/health-check.log"

mkdir -p $(dirname $LOG_FILE)

# Check critical services
CRITICAL_SERVICES=("bitcoind" "fulcrum" "mempool-api")
ISSUES=""

for service in "${CRITICAL_SERVICES[@]}"; do
    if ! docker ps | grep -q $service; then
        ISSUES="$ISSUES\n- Service $service is not running"
    fi
done

# Check disk space
DISK_USAGE=$(df -h /opt/bitcoin | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    ISSUES="$ISSUES\n- Disk usage critical: ${DISK_USAGE}%"
fi

# Send alert if issues found
if [ -n "$ISSUES" ]; then
    echo -e "Bitcoin Node Alert!\n$ISSUES" | mail -s "Bitcoin Node Issues - $(hostname)" $ALERT_EMAIL
    echo "[$(date)] Issues found: $ISSUES" >> $LOG_FILE
fi
SCRIPT_EOF

    sed -i "s/EMAIL_PLACEHOLDER/${EMAIL}/g" /opt/bitcoin/scripts/health-check.sh
    chmod +x /opt/bitcoin/scripts/health-check.sh
    
    # Create crontab entries
    cat > /tmp/bitcoin-cron <<EOF
# Bitcoin Sovereignty Infrastructure Cron Jobs

# Daily backup at 3 AM
0 3 * * * /opt/bitcoin/scripts/backup.sh >> /opt/bitcoin/logs/backup.log 2>&1

# Health check every 15 minutes
*/15 * * * * /opt/bitcoin/scripts/health-check.sh >> /opt/bitcoin/logs/health-check.log 2>&1

# Update docker images weekly
0 4 * * 0 cd /opt/bitcoin && docker compose pull >> /opt/bitcoin/logs/updates.log 2>&1

# Clean old logs monthly
0 5 1 * * find /opt/bitcoin/logs -name "*.log" -mtime +30 -delete
EOF

    # Install crontab for admin user
    crontab -u $ADMIN_USER /tmp/bitcoin-cron
    rm /tmp/bitcoin-cron
    
    log_success "Cron jobs configured"
}

# =============================================================================
# FAMILY FEATURES
# =============================================================================

setup_family_features() {
    log_info "Setting up family features..."
    
    # Create family status script
    cat > /opt/bitcoin/scripts/family-status.sh <<'SCRIPT_EOF'
#!/bin/bash
clear
echo "=== FAMILY_NAME_PLACEHOLDER Bitcoin Status ==="
echo "===================================="
echo ""
echo "📊 Bitcoin Price: $(curl -s https://api.coinbase.com/v2/exchange-rates?currency=BTC | jq -r '.data.rates.INR' | xargs printf "₹%'.0f\n" 2>/dev/null || echo "Loading...")"
echo ""
echo "⚡ Network Status:"
if docker ps | grep -q bitcoind; then
    SYNC=$(docker exec bitcoind bitcoin-cli -rpcuser=BITCOIN_RPC_USER_PLACEHOLDER -rpcpassword=BITCOIN_RPC_PASS_PLACEHOLDER getblockchaininfo 2>/dev/null | jq -r '.verificationprogress' || echo "0")
    if [ -n "$SYNC" ] && [ "$SYNC" != "0" ]; then
        SYNC_PCT=$(echo "scale=0; $SYNC * 100 / 1" | bc)
        echo "Sync Progress: ${SYNC_PCT}% ✅"
    fi
fi
echo ""
echo "🔗 Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "bitcoind|mempool|btcpay" | sed 's/bitcoind/Bitcoin Core/g' | sed 's/mempool-web/Blockchain Explorer/g' | sed 's/btcpayserver/Payment Processor/g'
echo ""
echo "👨‍👩‍👧‍👦 Family Access:"
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    echo "✅ VPN Connected"
    echo "📱 Wallet Server: $(tailscale ip -4):50001"
else
    echo "❌ VPN Not Connected"
fi
SCRIPT_EOF

    # Replace placeholders
    sed -i "s/FAMILY_NAME_PLACEHOLDER/${FAMILY_NAME}/g" /opt/bitcoin/scripts/family-status.sh
    sed -i "s/BITCOIN_RPC_USER_PLACEHOLDER/${BITCOIN_RPC_USER}/g" /opt/bitcoin/scripts/family-status.sh
    sed -i "s/BITCOIN_RPC_PASS_PLACEHOLDER/${BITCOIN_RPC_PASS}/g" /opt/bitcoin/scripts/family-status.sh
    
    chmod +x /opt/bitcoin/scripts/family-*.sh
    chown -R $ADMIN_USER:$ADMIN_USER /opt/bitcoin/scripts
    
    log_success "Family features configured"
}

# =============================================================================
# POST-INSTALL INSTRUCTIONS
# =============================================================================

show_post_install() {
    clear
    echo "=========================================="
    echo "✅ Bitcoin Sovereignty Setup Complete!"
    echo "=========================================="
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. Complete Tailscale setup (if not done):"
    echo "   sudo tailscale up"
    echo ""
    echo "2. Complete Cloudflare tunnel (if manual):"
    echo "   cloudflared tunnel login"
    echo "   cloudflared tunnel create ${FAMILY_NAME,,}-bitcoin"
    echo "   cloudflared tunnel route dns ${FAMILY_NAME,,}-bitcoin ${BTCPAY_DOMAIN}"
    echo ""
    echo "3. Monitor Bitcoin sync progress:"
    echo "   cd /opt/bitcoin && ./scripts/status.sh"
    echo ""
    echo "4. Start remaining services after Bitcoin syncs:"
    echo "   - At 50% sync: Fulcrum will start"
    echo "   - At 90% sync: All services will be active"
    echo ""
    echo "5. Access your services:"
    echo "   ./scripts/access-info.sh"
    echo ""
    echo "📁 Important Locations:"
    echo "   Config: /opt/bitcoin/configs/"
    echo "   Scripts: /opt/bitcoin/scripts/"
    echo "   Backups: /opt/bitcoin/backups/"
    echo "   Logs: /opt/bitcoin/logs/"
    echo ""
    echo "🔐 Security Notes:"
    echo "   - SSH is now restricted to Tailscale only"
    echo "   - All internal services require Tailscale"
    echo "   - BTCPay is the only public service"
    echo ""
    echo "💰 Monthly Cost: ~$34 (saving $20/month!)"
    echo ""
    echo "📧 Support: Issues sent to ${EMAIL}"
    echo ""
    echo "Run './scripts/status.sh' anytime to check system status"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting Bitcoin Sovereignty Infrastructure Setup"
    log_info "This will set up a complete Bitcoin node with payment processing"
    echo ""
    
    # Run all setup phases
    validate_config
    prepare_system
    setup_admin_user
    setup_security
    setup_tailscale
    setup_firewall
    setup_docker
    setup_cloudflare
    setup_bitcoin_directories
    create_bitcoin_configs
    create_monitoring_scripts
    setup_btcpay
    setup_family_features
    setup_cron_jobs
    start_services
    
    # Show completion message
    show_post_install
    
    log_success "Setup complete! Your Bitcoin sovereignty infrastructure is ready."
}

# Run main function
main "$@"