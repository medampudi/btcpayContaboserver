#!/bin/bash
# 🔗 Tailscale & Cloudflare Automated Setup
# For Medampudi Family Bitcoin Infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - CHANGE THESE VALUES
DOMAIN_NAME="your-domain.com"
BTCPAY_SUBDOMAIN="pay"
TAILSCALE_AUTHKEY=""  # Get from https://login.tailscale.com/admin/settings/keys
CLOUDFLARE_EMAIL="your-email@domain.com"
CLOUDFLARE_API_TOKEN=""  # Get from Cloudflare dashboard

echo -e "${BLUE}🔗 Tailscale & Cloudflare Setup for Medampudi Family${NC}"
echo -e "${YELLOW}Secure VPN + Public Bitcoin Payment Gateway${NC}"
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

# Check if running as correct user
if [[ $EUID -eq 0 ]]; then
   print_error "Do not run as root. Run as ubuntu user with sudo access."
   exit 1
fi

# Verify we're running as ubuntu user (recommended for OVH)
if [ "$USER" != "ubuntu" ]; then
   print_warning "Script is optimized for 'ubuntu' user on OVH servers"
   print_warning "Current user: $USER"
   read -p "Continue anyway? (y/N): " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Validate configuration
if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "your-domain.com" ]; then
    print_error "Please set DOMAIN_NAME in the script"
    exit 1
fi

echo -e "${BLUE}📋 Configuration Check${NC}"
echo "Domain: $DOMAIN_NAME"
echo "BTCPay URL: https://$BTCPAY_SUBDOMAIN.$DOMAIN_NAME"
echo "Tailscale Auth Key: ${TAILSCALE_AUTHKEY:+Set}${TAILSCALE_AUTHKEY:-Not Set}"
echo "Cloudflare API Token: ${CLOUDFLARE_API_TOKEN:+Set}${CLOUDFLARE_API_TOKEN:-Not Set}"
echo ""

read -p "Continue with setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 1
fi

# Phase 1: Tailscale Setup
echo -e "${BLUE}🌐 Phase 1: Tailscale VPN Setup${NC}"

if ! command -v tailscale &> /dev/null; then
    print_status "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    print_warning "Tailscale already installed"
fi

if [ ! -z "$TAILSCALE_AUTHKEY" ]; then
    print_status "Connecting to Tailscale network..."
    sudo tailscale up \
        --authkey="$TAILSCALE_AUTHKEY" \
        --hostname="medampudi-bitcoin-node" \
        --accept-routes \
        --ssh
    
    TAILSCALE_IP=$(tailscale ip -4)
    print_status "Tailscale connected successfully!"
    print_status "Tailscale IP: $TAILSCALE_IP"
else
    print_warning "Tailscale auth key not provided"
    print_warning "Run manually: sudo tailscale up --hostname=medampudi-bitcoin-node"
    print_warning "Get auth key from: https://login.tailscale.com/admin/settings/keys"
    
    # Try to get IP if already connected
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
    if [ "$TAILSCALE_IP" != "Not connected" ]; then
        print_status "Tailscale already connected. IP: $TAILSCALE_IP"
    fi
fi

# Create Tailscale device management script
print_status "Creating Tailscale family management script..."

cat > /opt/bitcoin/scripts/tailscale-family.sh << 'EOF'
#!/bin/bash
# Tailscale Family Device Management

echo "🏠 Medampudi Family Tailscale Network"
echo "===================================="
echo ""

# Show current device status
echo "📱 Connected Devices:"
tailscale status

echo ""
echo "🔗 This Node Information:"
echo "Hostname: $(tailscale status | grep $(hostname) | awk '{print $1}')"
echo "IP Address: $(tailscale ip -4)"
echo "Status: $(tailscale status | grep $(hostname) | awk '{print $3}')"

echo ""
echo "👨‍👩‍👧‍👦 Family Device Setup Instructions:"
echo "1. Install Tailscale app on device"
echo "2. Sign in with family account"
echo "3. Device will auto-connect to family network"
echo "4. Access Bitcoin services via this IP: $(tailscale ip -4)"

echo ""
echo "📋 Family Access URLs:"
TAILSCALE_IP=$(tailscale ip -4)
echo "Mempool Explorer:    http://$TAILSCALE_IP:8080"
echo "Bitcoin Explorer:    http://$TAILSCALE_IP:3002"  
echo "Electrum Server:     $TAILSCALE_IP:50001"
echo "Lightning Node:      $TAILSCALE_IP:9735"
echo "SSH Access:          ssh $(whoami)@$TAILSCALE_IP"

echo ""
echo "🔧 Management Commands:"
echo "Add device:     tailscale invite user@email.com"
echo "Remove device:  tailscale lock disable-device [device-id]"
echo "Show logs:      sudo journalctl -u tailscaled"
EOF

chmod +x /opt/bitcoin/scripts/tailscale-family.sh

# Phase 2: Cloudflare Setup
echo -e "${BLUE}☁️  Phase 2: Cloudflare Tunnel Setup${NC}"

if ! command -v cloudflared &> /dev/null; then
    print_status "Installing Cloudflared..."
    # Add Cloudflare repository
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
    sudo apt update
    sudo apt install -y cloudflared
else
    print_warning "Cloudflared already installed"
fi

print_status "Setting up Cloudflare Tunnel..."

# Check if already logged in
if [ ! -f ~/.cloudflared/cert.pem ]; then
    print_warning "Cloudflare login required"
    print_warning "Run: cloudflared tunnel login"
    print_warning "This will open browser for authentication"
    echo ""
    
    read -p "Login to Cloudflare now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cloudflared tunnel login
    else
        print_error "Cloudflare authentication required to continue"
        exit 1
    fi
fi

# Create tunnel
TUNNEL_NAME="medampudi-bitcoin"
TUNNEL_ID=""

# Check if tunnel already exists
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    print_warning "Tunnel $TUNNEL_NAME already exists (ID: $TUNNEL_ID)"
else
    print_status "Creating Cloudflare tunnel: $TUNNEL_NAME"
    cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    print_status "Tunnel created with ID: $TUNNEL_ID"
fi

# Create tunnel configuration
print_status "Creating tunnel configuration..."
sudo mkdir -p /etc/cloudflared

sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: /home/ubuntu/.cloudflared/$TUNNEL_ID.json

originRequest:
  noTLSVerify: true
  connectTimeout: 30s
  tlsTimeout: 30s
  keepAliveConnections: 10

ingress:
  # BTCPay Server - Public Access
  - hostname: $BTCPAY_SUBDOMAIN.$DOMAIN_NAME
    service: http://localhost:80
    originRequest:
      noTLSVerify: true
  
  # All other services are Tailscale-only
  - service: http_status:404
    
# Metrics and health check
metrics: 127.0.0.1:9090
EOF

# Copy credentials to system location
if [ -f ~/.cloudflared/$TUNNEL_ID.json ]; then
    sudo cp ~/.cloudflared/$TUNNEL_ID.json /etc/cloudflared/
    sudo chown root:root /etc/cloudflared/$TUNNEL_ID.json
    sudo chmod 600 /etc/cloudflared/$TUNNEL_ID.json
    print_status "Tunnel credentials configured"
fi

# Install tunnel as system service
print_status "Installing tunnel as system service..."
sudo cloudflared service install --config /etc/cloudflared/config.yml
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Wait for tunnel to come online
print_status "Waiting for tunnel to connect..."
sleep 10

# Check tunnel status
if sudo systemctl is-active --quiet cloudflared; then
    print_status "Cloudflare tunnel is running"
else
    print_error "Cloudflare tunnel failed to start"
    print_error "Check logs: sudo journalctl -u cloudflared"
fi

# Phase 3: DNS Configuration
echo -e "${BLUE}🌐 Phase 3: DNS Configuration${NC}"

if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    print_status "Configuring DNS automatically..."
    
    # Get Zone ID
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN_NAME" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    if [ "$ZONE_ID" != "null" ] && [ ! -z "$ZONE_ID" ]; then
        # Create DNS record
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data '{
                "type": "CNAME",
                "name": "'$BTCPAY_SUBDOMAIN'",
                "content": "'$TUNNEL_ID'.cfargotunnel.com",
                "proxied": true,
                "comment": "BTCPay Server for Medampudi Family Bitcoin Infrastructure"
            }' | jq .
        
        print_status "DNS record created automatically"
    else
        print_error "Could not get Zone ID for $DOMAIN_NAME"
        print_warning "Configure DNS manually in Cloudflare dashboard"
    fi
else
    print_warning "Cloudflare API token not provided"
    print_warning "Configure DNS manually:"
    echo "1. Go to Cloudflare dashboard"
    echo "2. Select domain: $DOMAIN_NAME"
    echo "3. Add DNS record:"
    echo "   Type: CNAME"
    echo "   Name: $BTCPAY_SUBDOMAIN"
    echo "   Target: $TUNNEL_ID.cfargotunnel.com"
    echo "   Proxy: Enabled (orange cloud)"
fi

# Phase 4: Security Configuration  
echo -e "${BLUE}🛡️  Phase 4: Security Configuration${NC}"

if [ "$TAILSCALE_IP" != "Not connected" ] && [ ! -z "$TAILSCALE_IP" ]; then
    print_status "Configuring SSH to use Tailscale only..."
    
    # Configure SSH to listen on Tailscale IP only
    sudo tee /etc/ssh/sshd_config.d/99-tailscale-only.conf > /dev/null <<EOF
# Medampudi Family - SSH via Tailscale only
ListenAddress $TAILSCALE_IP
ListenAddress 127.0.0.1
AllowUsers $(whoami)
EOF
    
    print_warning "SSH will be restricted to Tailscale IP after restart"
    print_warning "Test Tailscale SSH before restarting: ssh $(whoami)@$TAILSCALE_IP"
    
    # Update firewall to remove public SSH
    print_status "Updating firewall rules..."
    sudo ufw delete allow 22/tcp || true
    sudo ufw reload
    
    print_status "SSH secured via Tailscale only"
else
    print_warning "Tailscale IP not available, skipping SSH restriction"
fi

# Phase 5: Create Management Scripts
echo -e "${BLUE}📋 Phase 5: Creating Management Scripts${NC}"

# Cloudflare management script
cat > /opt/bitcoin/scripts/cloudflare-manage.sh << EOF
#!/bin/bash
# Cloudflare Tunnel Management for Medampudi Family

case "\$1" in
    "status")
        echo "☁️  Cloudflare Tunnel Status:"
        sudo systemctl status cloudflared
        echo ""
        echo "🌐 Tunnel Information:"
        cloudflared tunnel list
        ;;
    "restart")
        echo "🔄 Restarting Cloudflare tunnel..."
        sudo systemctl restart cloudflared
        sleep 5
        sudo systemctl status cloudflared
        ;;
    "logs")
        echo "📋 Cloudflare Tunnel Logs:"
        sudo journalctl -u cloudflared -f
        ;;
    "test")
        echo "🧪 Testing BTCPay Server access..."
        curl -s -o /dev/null -w "%{http_code}" https://$BTCPAY_SUBDOMAIN.$DOMAIN_NAME
        echo " - BTCPay Server response"
        ;;
    *)
        echo "Cloudflare Tunnel Management"
        echo "Usage: \$0 {status|restart|logs|test}"
        echo ""
        echo "Commands:"
        echo "  status  - Show tunnel status"
        echo "  restart - Restart tunnel service"  
        echo "  logs    - Show tunnel logs"
        echo "  test    - Test BTCPay access"
        ;;
esac
EOF

chmod +x /opt/bitcoin/scripts/cloudflare-manage.sh

# Network diagnostics script
cat > /opt/bitcoin/scripts/network-diagnostics.sh << 'EOF'
#!/bin/bash
# Network Diagnostics for Medampudi Family Bitcoin Infrastructure

echo "🌐 Network Diagnostics for Medampudi Family"
echo "=========================================="
echo ""

# Tailscale Status
echo "🔗 Tailscale Status:"
if command -v tailscale &> /dev/null; then
    tailscale status | head -10
    echo "IP: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
else
    echo "❌ Tailscale not installed"
fi
echo ""

# Cloudflare Tunnel Status
echo "☁️  Cloudflare Tunnel Status:"
if sudo systemctl is-active --quiet cloudflared; then
    echo "✅ Running"
    cloudflared tunnel list 2>/dev/null | head -5
else
    echo "❌ Not running"
fi
echo ""

# Port Status
echo "🔌 Port Status:"
echo "Bitcoin P2P (8333): $(ss -tuln | grep :8333 > /dev/null && echo "✅ Open" || echo "❌ Closed")"
echo "Lightning (9735): $(ss -tuln | grep :9735 > /dev/null && echo "✅ Open" || echo "❌ Closed")"
echo "HTTP (80): $(ss -tuln | grep :80 > /dev/null && echo "✅ Open" || echo "❌ Closed")"
echo "HTTPS (443): $(ss -tuln | grep :443 > /dev/null && echo "✅ Open" || echo "❌ Closed")"
echo ""

# Firewall Status
echo "🛡️  Firewall Status:"
sudo ufw status | head -10
echo ""

# DNS Resolution Test
echo "🌍 DNS Resolution Test:"
if [ ! -z "$DOMAIN_NAME" ] && [ "$DOMAIN_NAME" != "your-domain.com" ]; then
    nslookup "$BTCPAY_SUBDOMAIN.$DOMAIN_NAME" | grep -A1 "Name:" || echo "❌ DNS resolution failed"
else
    echo "⚠️  Domain not configured"
fi
echo ""

# Bitcoin Network Connectivity
echo "₿ Bitcoin Network Test:"
nc -z -w3 seed.bitcoin.sipa.be 8333 && echo "✅ Can connect to Bitcoin network" || echo "❌ Bitcoin network connection failed"
echo ""

echo "📞 Support Information:"
echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
echo "Public Domain: https://$BTCPAY_SUBDOMAIN.$DOMAIN_NAME"
echo "Local Services: Available via Tailscale only"
EOF

chmod +x /opt/bitcoin/scripts/network-diagnostics.sh

# Final setup summary
echo ""
echo -e "${BLUE}🎉 Tailscale & Cloudflare Setup Complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

print_status "Network configuration completed successfully"

echo ""
echo -e "${YELLOW}📋 Setup Summary:${NC}"
echo "🔗 Tailscale IP: ${TAILSCALE_IP:-Not connected}"
echo "☁️  Cloudflare Tunnel: $TUNNEL_NAME ($TUNNEL_ID)"
echo "🌐 BTCPay URL: https://$BTCPAY_SUBDOMAIN.$DOMAIN_NAME"
echo ""

echo -e "${YELLOW}🎯 Next Steps:${NC}"
echo "1. 📱 Install Tailscale on family devices"
echo "2. 🧪 Test BTCPay Server access: https://$BTCPAY_SUBDOMAIN.$DOMAIN_NAME"
echo "3. 👨‍👩‍👧‍👦 Share access info with family: ./scripts/tailscale-family.sh"
echo "4. 🔧 Monitor services: ./scripts/network-diagnostics.sh"
echo ""

echo -e "${YELLOW}📞 Family Device Setup:${NC}"
echo "Send this to family members:"
echo "1. Install Tailscale app"
echo "2. Sign in with family account"  
echo "3. Access Bitcoin services via: $TAILSCALE_IP"
echo ""

echo -e "${GREEN}🏠 Medampudi Family Bitcoin Network is Ready!${NC}"

# Create desktop shortcut for easy access
if [ -d "/home/$(whoami)/Desktop" ]; then
    cat > "/home/$(whoami)/Desktop/Family-Bitcoin-Status.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Medampudi Family Bitcoin Status
Comment=Check family Bitcoin infrastructure status
Exec=gnome-terminal -- /opt/bitcoin/scripts/bitcoin-status.sh
Icon=utilities-terminal
Terminal=true
Categories=Utility;
EOF
    chmod +x "/home/$(whoami)/Desktop/Family-Bitcoin-Status.desktop"
    print_status "Desktop shortcut created for easy access"
fi