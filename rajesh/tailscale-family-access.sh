#!/bin/bash

# Tailscale Family Access Script
# Generates family-friendly access information

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)

if [ -z "$TAILSCALE_IP" ]; then
    echo "❌ Tailscale not connected. Please connect first:"
    echo "   sudo tailscale up"
    exit 1
fi

clear
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🏠 Family Bitcoin Services - Tailscale Access${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}📱 Share these links with your family:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🔒 Private Services (Tailscale Required):${NC}"
echo -e "📊 Mempool Explorer:    http://$TAILSCALE_IP:8080"
echo -e "🔍 Bitcoin Explorer:    http://$TAILSCALE_IP:3002"
echo -e "⚡ Lightning Dashboard: http://$TAILSCALE_IP:3000"
echo ""
echo -e "${YELLOW}🌐 Public Service (No Tailscale Needed):${NC}"
echo -e "💳 BTCPay Server:       https://pay.yourdomain.com"
echo ""

echo -e "${PURPLE}📱 Electrum Wallet Setup:${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Server: ${TAILSCALE_IP}"
echo -e "Port:   50001 (TCP) or 50002 (SSL)"
echo ""
echo -e "Instructions:"
echo -e "1. Open Electrum wallet"
echo -e "2. Tools → Network → Uncheck 'Select server automatically'"
echo -e "3. Enter server: ${TAILSCALE_IP} port: 50001"
echo -e "4. Connect and enjoy private Bitcoin verification!"
echo ""

echo -e "${BLUE}🔐 SSH Access (Tech Users):${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "ssh admin@${TAILSCALE_IP}"
echo ""

echo -e "${GREEN}📋 Family Onboarding Steps:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "1. Send Tailscale invitation from: https://login.tailscale.com/admin/machines"
echo -e "2. Help them install Tailscale app on their device"
echo -e "3. Share the service URLs above"
echo -e "4. Test one service together"
echo -e "5. They bookmark the URLs for easy access"
echo ""

echo -e "${YELLOW}💡 Pro Tips:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "• Family members should bookmark these URLs"
echo -e "• Tailscale works automatically in the background"
echo -e "• Services work from anywhere (home, office, travel)"
echo -e "• BTCPay doesn't require Tailscale (already public)"
echo -e "• SSH is only for tech-savvy family members"
echo ""

# Create shareable text file
cat > /tmp/family-bitcoin-access.txt << EOF
🏠 Family Bitcoin Services Access

🔒 Private Services (Install Tailscale first):
📊 Mempool Explorer:    http://$TAILSCALE_IP:8080
🔍 Bitcoin Explorer:    http://$TAILSCALE_IP:3002
⚡ Lightning Dashboard: http://$TAILSCALE_IP:3000

🌐 Public Service (Works without Tailscale):
💳 BTCPay Server:       https://pay.yourdomain.com

📱 For Bitcoin Wallet (Electrum):
Server: $TAILSCALE_IP
Port: 50001

📋 Setup Steps:
1. Install Tailscale app on your phone/computer
2. Join our family network (click invitation link)
3. Bookmark these URLs
4. Start exploring Bitcoin!

❓ Need help? Ask in family chat!
EOF

echo -e "${GREEN}✅ Created shareable file: /tmp/family-bitcoin-access.txt${NC}"
echo -e "${GREEN}📱 Send this file to family members via chat/email${NC}"
echo ""

# Show current Tailscale status
echo -e "${BLUE}🔗 Current Tailscale Network Status:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
tailscale status --peers | head -10
echo ""

echo -e "${PURPLE}🎯 Want to invite someone? Run: tailscale web${NC}"
echo -e "${PURPLE}📊 Check services: ./family-status.sh${NC}"