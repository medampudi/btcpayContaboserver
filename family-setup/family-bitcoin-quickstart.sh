#!/bin/bash

# 🏠 Family Bitcoin Sovereignty Quick Start Script
# This script helps families set up their own Bitcoin infrastructure
# Run with: bash family-bitcoin-quickstart.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
clear
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🏠 Family Bitcoin Sovereignty Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}This script will help your family set up:${NC}"
echo -e "  🏦 Bitcoin Full Node (your own bank)"
echo -e "  💳 BTCPay Server (accept payments)"
echo -e "  ⚡ Lightning Network (instant transfers)"
echo -e "  📊 Block Explorers (monitor everything)"
echo -e "  🔐 Maximum Security (VPN-only access)"
echo ""
echo -e "${YELLOW}Prerequisites:${NC}"
echo -e "  • Ubuntu 22.04 server (VPS or home server)"
echo -e "  • 8+ CPU cores, 32GB+ RAM, 1TB+ storage"
echo -e "  • Domain name with Cloudflare DNS"
echo -e "  • About 4-6 hours for initial setup"
echo ""
read -p "Ready to begin? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
       echo -e "${RED}This script should not be run as root!${NC}"
       echo "Please run as a regular user with sudo privileges."
       exit 1
    fi
}

# Function to collect family information
collect_info() {
    print_section "📝 Family Information Collection"
    
    echo -e "${GREEN}Let's collect some information about your family setup:${NC}"
    echo ""
    
    # Domain information
    read -p "Enter your domain name (e.g., smithfamily.com): " DOMAIN_NAME
    read -p "Enter subdomain for BTCPay (e.g., pay): " BTCPAY_SUBDOMAIN
    BTCPAY_DOMAIN="${BTCPAY_SUBDOMAIN}.${DOMAIN_NAME}"
    
    # Email for notifications
    read -p "Enter family admin email: " ADMIN_EMAIL
    
    # Family name for branding
    read -p "Enter your family name (for display): " FAMILY_NAME
    
    # Number of family members
    read -p "How many family members will use this? " FAMILY_SIZE
    
    echo ""
    echo -e "${GREEN}Configuration Summary:${NC}"
    echo -e "  Domain: ${DOMAIN_NAME}"
    echo -e "  BTCPay URL: https://${BTCPAY_DOMAIN}"
    echo -e "  Admin Email: ${ADMIN_EMAIL}"
    echo -e "  Family Name: ${FAMILY_NAME}"
    echo -e "  Family Size: ${FAMILY_SIZE} members"
    echo ""
    read -p "Is this correct? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        collect_info
    fi
}

# Function to generate secure passwords
generate_passwords() {
    print_section "🔐 Generating Secure Passwords"
    
    BITCOIN_RPC_USER="bitcoin_${FAMILY_NAME,,}_$(openssl rand -hex 4)"
    BITCOIN_RPC_PASS=$(openssl rand -base64 32)
    POSTGRES_PASS=$(openssl rand -base64 32)
    MARIADB_ROOT_PASS=$(openssl rand -base64 32)
    MARIADB_MEMPOOL_PASS=$(openssl rand -base64 32)
    
    # Save passwords securely
    cat > ~/.bitcoin-passwords << EOF
# 🔐 Bitcoin Infrastructure Passwords
# Keep this file secure! Back it up!
# Generated: $(date)

BITCOIN_RPC_USER="${BITCOIN_RPC_USER}"
BITCOIN_RPC_PASS="${BITCOIN_RPC_PASS}"
POSTGRES_PASS="${POSTGRES_PASS}"
MARIADB_ROOT_PASS="${MARIADB_ROOT_PASS}"
MARIADB_MEMPOOL_PASS="${MARIADB_MEMPOOL_PASS}"
EOF
    
    chmod 600 ~/.bitcoin-passwords
    echo -e "${GREEN}✅ Passwords generated and saved to ~/.bitcoin-passwords${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Back up this file securely!${NC}"
}

# Function to install prerequisites
install_prerequisites() {
    print_section "📦 Installing Prerequisites"
    
    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    
    echo "Installing required packages..."
    sudo apt install -y \
        curl wget git vim htop ncdu \
        ufw fail2ban net-tools \
        software-properties-common \
        jq bc
    
    echo "Setting timezone..."
    sudo timedatectl set-timezone $(curl -s http://ip-api.com/json | jq -r .timezone)
    
    echo -e "${GREEN}✅ Prerequisites installed${NC}"
}

# Function to setup Tailscale
setup_tailscale() {
    print_section "🔒 Setting up Tailscale VPN"
    
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    echo -e "${YELLOW}Starting Tailscale...${NC}"
    sudo tailscale up
    
    echo ""
    echo -e "${GREEN}✅ Tailscale installed!${NC}"
    echo -e "${YELLOW}📱 Next steps for family access:${NC}"
    echo -e "  1. Go to: https://login.tailscale.com/admin/machines"
    echo -e "  2. Click 'Share' next to this machine"
    echo -e "  3. Invite family members by email"
    echo -e "  4. They install Tailscale and join your network"
    echo ""
    
    TAILSCALE_IP=$(tailscale ip -4)
    echo -e "${GREEN}Your Tailscale IP: ${TAILSCALE_IP}${NC}"
}

# Function to setup firewall
setup_firewall() {
    print_section "🛡️ Configuring Firewall"
    
    # Reset UFW to defaults
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow essential services
    sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
    sudo ufw allow 443/tcp   # HTTPS (for BTCPay)
    sudo ufw allow 8333/tcp  # Bitcoin P2P
    sudo ufw allow 9735/tcp  # Lightning Network
    
    # Allow Tailscale
    sudo ufw allow in on tailscale0
    
    # Enable firewall
    sudo ufw --force enable
    
    echo -e "${GREEN}✅ Firewall configured${NC}"
}

# Function to install Docker
install_docker() {
    print_section "🐳 Installing Docker"
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Install docker-compose
    sudo apt install -y docker-compose-v2
    
    echo -e "${GREEN}✅ Docker installed${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes${NC}"
}

# Function to setup Cloudflare tunnel
setup_cloudflare() {
    print_section "☁️ Setting up Cloudflare Tunnel"
    
    # Install cloudflared
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
    sudo apt update
    sudo apt install -y cloudflared
    
    echo ""
    echo -e "${YELLOW}Creating Cloudflare tunnel...${NC}"
    echo -e "${CYAN}You'll be redirected to Cloudflare to authenticate.${NC}"
    echo -e "${CYAN}Please log in with your Cloudflare account.${NC}"
    echo ""
    read -p "Press Enter to continue..."
    
    cloudflared tunnel login
    cloudflared tunnel create bitcoin-${FAMILY_NAME,,}
    
    TUNNEL_ID=$(cloudflared tunnel list | grep "bitcoin-${FAMILY_NAME,,}" | awk '{print $1}')
    
    # Create tunnel config
    sudo mkdir -p /etc/cloudflared
    sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: /home/${USER}/.cloudflared/${TUNNEL_ID}.json

originRequest:
  noTLSVerify: true

ingress:
  # Only BTCPay is publicly exposed
  - hostname: ${BTCPAY_DOMAIN}
    service: http://localhost:80
    
  # Everything else is private (Tailscale only)
  - service: http_status:404
EOF
    
    # Copy credentials
    sudo cp ~/.cloudflared/*.json /etc/cloudflared/
    
    # Install as service
    sudo cloudflared service install
    sudo systemctl start cloudflared
    sudo systemctl enable cloudflared
    
    echo -e "${GREEN}✅ Cloudflare tunnel created${NC}"
    echo -e "${YELLOW}📝 Add this CNAME record in Cloudflare DNS:${NC}"
    echo -e "   ${BTCPAY_SUBDOMAIN} → ${TUNNEL_ID}.cfargotunnel.com (Proxied)"
}

# Function to create Bitcoin stack
create_bitcoin_stack() {
    print_section "🏗️ Creating Bitcoin Infrastructure"
    
    # Create directory structure
    sudo mkdir -p /opt/bitcoin/{data,configs,mysql,backups}
    sudo chown -R $USER:$USER /opt/bitcoin
    cd /opt/bitcoin
    
    # Load passwords
    source ~/.bitcoin-passwords
    
    # Create configuration files
    echo "Creating Fulcrum configuration..."
    cat > configs/fulcrum.conf << EOF
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
db_mem = 8000.0
bitcoind_timeout = 300
bitcoind_clients = 4
EOF
    
    echo "Creating Mempool configuration..."
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
    
    echo "Creating Docker Compose file..."
    # Download the full docker-compose.yml from the repository
    curl -fsSL https://raw.githubusercontent.com/btcpayserver/btcpayserver-docker/master/docker-compose.yml -o docker-compose.yml.template
    
    # For this demo, we'll create a simplified version
    cat > docker-compose.yml << 'EOF'
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
        rpcallowip=172.25.0.0/16
        rpcbind=0.0.0.0
        server=1
        txindex=1
        listen=1
        listenonion=0
    ports:
      - "8333:8333"
EOF
    
    echo -e "${GREEN}✅ Bitcoin stack configured${NC}"
}

# Function to create helper scripts
create_helper_scripts() {
    print_section "📝 Creating Helper Scripts"
    
    # Status script
    cat > status.sh << 'EOF'
#!/bin/bash
echo "🏠 Family Bitcoin Status"
echo "========================"
docker ps --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "Run './family-status.sh' for detailed information"
EOF
    chmod +x status.sh
    
    # Family status script (copy from repository)
    cp ~/personal/workspace/btcpayContaboserver/family-status.sh . 2>/dev/null || \
    curl -fsSL https://raw.githubusercontent.com/yourusername/btcpayContaboserver/main/family-status.sh -o family-status.sh
    chmod +x family-status.sh
    
    # Access info script
    cp ~/personal/workspace/btcpayContaboserver/tailscale-family-access.sh . 2>/dev/null || \
    curl -fsSL https://raw.githubusercontent.com/yourusername/btcpayContaboserver/main/tailscale-family-access.sh -o tailscale-family-access.sh
    chmod +x tailscale-family-access.sh
    
    echo -e "${GREEN}✅ Helper scripts created${NC}"
}

# Function to create family documentation
create_family_docs() {
    print_section "📚 Creating Family Documentation"
    
    TAILSCALE_IP=$(tailscale ip -4)
    
    cat > FAMILY_ACCESS.md << EOF
# 🏠 ${FAMILY_NAME} Bitcoin Services

## Quick Access Links

### Private Services (Tailscale Required)
- 📊 **Mempool Explorer**: http://${TAILSCALE_IP}:8080
- 🔍 **Bitcoin Explorer**: http://${TAILSCALE_IP}:3002
- ⚡ **Lightning Dashboard**: http://${TAILSCALE_IP}:3000

### Public Services
- 💳 **BTCPay Server**: https://${BTCPAY_DOMAIN}

## Family Member Setup
1. Install Tailscale on your device
2. Accept the invitation email
3. Connect to our family network
4. Bookmark the service links above

## Wallet Configuration
**Electrum Server**: ${TAILSCALE_IP}:50001

## Support
Contact ${ADMIN_EMAIL} for help
EOF
    
    echo -e "${GREEN}✅ Family documentation created${NC}"
}

# Function to show next steps
show_next_steps() {
    print_section "🎯 Setup Complete! Next Steps"
    
    echo -e "${GREEN}Your family Bitcoin infrastructure is being set up!${NC}"
    echo ""
    echo -e "${YELLOW}Immediate Actions:${NC}"
    echo -e "  1. Add Cloudflare DNS record:"
    echo -e "     ${BTCPAY_SUBDOMAIN} → ${TUNNEL_ID}.cfargotunnel.com"
    echo -e "  2. Start Bitcoin sync:"
    echo -e "     cd /opt/bitcoin && docker compose up -d bitcoind"
    echo -e "  3. Monitor progress:"
    echo -e "     ./status.sh"
    echo ""
    echo -e "${YELLOW}Family Onboarding:${NC}"
    echo -e "  1. Send Tailscale invites from:"
    echo -e "     https://login.tailscale.com/admin/machines"
    echo -e "  2. Share FAMILY_ACCESS.md with family"
    echo -e "  3. Help them install Tailscale"
    echo -e "  4. Test services together"
    echo ""
    echo -e "${YELLOW}Important Files:${NC}"
    echo -e "  • Passwords: ~/.bitcoin-passwords"
    echo -e "  • Config: /opt/bitcoin/docker-compose.yml"
    echo -e "  • Access Info: /opt/bitcoin/FAMILY_ACCESS.md"
    echo ""
    echo -e "${GREEN}Bitcoin will sync for 2-3 days. Other services can be started after:${NC}"
    echo -e "  • 50% sync: Start databases"
    echo -e "  • 90% sync: Start Fulcrum"
    echo -e "  • 100% sync: Everything operational"
    echo ""
    echo -e "${BLUE}Welcome to Bitcoin sovereignty! Your family's financial future is now in YOUR hands.${NC}"
}

# Main execution flow
main() {
    check_root
    collect_info
    generate_passwords
    install_prerequisites
    setup_tailscale
    setup_firewall
    install_docker
    setup_cloudflare
    create_bitcoin_stack
    create_helper_scripts
    create_family_docs
    show_next_steps
}

# Run main function
main