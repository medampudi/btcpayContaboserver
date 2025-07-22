#!/bin/bash
# 🔍 OVH Ubuntu Server Verification Script
# Verify your OVH server is ready for Medampudi Family Bitcoin setup

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 OVH Ubuntu Server Verification for Medampudi Family${NC}"
echo "=================================================="
echo ""

# Check 1: User verification
echo -e "${BLUE}👤 User Verification${NC}"
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"

if [ "$CURRENT_USER" = "ubuntu" ]; then
    echo -e "${GREEN}✅ Running as ubuntu user (correct for OVH)${NC}"
else
    echo -e "${YELLOW}⚠️  Running as: $CURRENT_USER (OVH typically uses 'ubuntu')${NC}"
fi

# Check 2: Sudo access
echo -e "\n${BLUE}🔐 Sudo Access Verification${NC}"
if sudo -n true 2>/dev/null; then
    echo -e "${GREEN}✅ Passwordless sudo access confirmed${NC}"
elif sudo -v; then
    echo -e "${GREEN}✅ Sudo access confirmed${NC}"
else
    echo -e "${RED}❌ No sudo access available${NC}"
    exit 1
fi

# Check 3: OS Version
echo -e "\n${BLUE}🖥️  Operating System${NC}"
OS_VERSION=$(lsb_release -d | cut -f2)
echo "OS: $OS_VERSION"

if echo "$OS_VERSION" | grep -q "Ubuntu 24.04"; then
    echo -e "${GREEN}✅ Ubuntu 24.04 confirmed${NC}"
elif echo "$OS_VERSION" | grep -q "Ubuntu"; then
    echo -e "${YELLOW}⚠️  Ubuntu detected but not 24.04${NC}"
else
    echo -e "${RED}❌ Not running Ubuntu${NC}"
fi

# Check 4: Network connectivity
echo -e "\n${BLUE}🌐 Network Connectivity${NC}"
if ping -c 1 google.com >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Internet connectivity working${NC}"
else
    echo -e "${RED}❌ No internet connectivity${NC}"
fi

# Check 5: Disk space
echo -e "\n${BLUE}💾 Storage Check${NC}"
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo "Available space: ${AVAILABLE_SPACE}GB"

if [ "$AVAILABLE_SPACE" -gt 500 ]; then
    echo -e "${GREEN}✅ Sufficient storage for Bitcoin node (${AVAILABLE_SPACE}GB available)${NC}"
elif [ "$AVAILABLE_SPACE" -gt 200 ]; then
    echo -e "${YELLOW}⚠️  Limited storage (${AVAILABLE_SPACE}GB) - consider pruned node${NC}"
else
    echo -e "${RED}❌ Insufficient storage for Bitcoin node${NC}"
fi

# Check 6: RAM
echo -e "\n${BLUE}🧠 Memory Check${NC}"
TOTAL_RAM=$(free -g | awk 'NR==2{print $2}')
echo "Total RAM: ${TOTAL_RAM}GB"

if [ "$TOTAL_RAM" -gt 15 ]; then
    echo -e "${GREEN}✅ Sufficient RAM for Bitcoin infrastructure (${TOTAL_RAM}GB)${NC}"
elif [ "$TOTAL_RAM" -gt 7 ]; then
    echo -e "${YELLOW}⚠️  Adequate RAM (${TOTAL_RAM}GB) - will work but tight${NC}"
else
    echo -e "${RED}❌ Insufficient RAM for full Bitcoin stack${NC}"
fi

# Check 7: Required packages check
echo -e "\n${BLUE}📦 System Packages${NC}"
MISSING_PACKAGES=""

for pkg in curl wget git sudo; do
    if command -v $pkg >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $pkg installed${NC}"
    else
        echo -e "${RED}❌ $pkg missing${NC}"
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
    fi
done

# Check 8: Firewall status
echo -e "\n${BLUE}🛡️  Firewall Status${NC}"
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(sudo ufw status | head -1)
    echo "UFW Status: $UFW_STATUS"
    if echo "$UFW_STATUS" | grep -q "inactive"; then
        echo -e "${YELLOW}⚠️  UFW firewall is inactive (will be configured during setup)${NC}"
    else
        echo -e "${GREEN}✅ UFW firewall is active${NC}"
    fi
else
    echo -e "${RED}❌ UFW firewall not installed${NC}"
fi

# Check 9: SSH configuration
echo -e "\n${BLUE}🔑 SSH Configuration${NC}"
SSH_PORT=$(sudo ss -tlnp | grep :22 | wc -l)
if [ "$SSH_PORT" -gt 0 ]; then
    echo -e "${GREEN}✅ SSH service running on port 22${NC}"
else
    echo -e "${RED}❌ SSH service not running on port 22${NC}"
fi

# Check 10: Home directory permissions
echo -e "\n${BLUE}🏠 Home Directory${NC}"
HOME_PERMS=$(stat -c "%a" ~)
echo "Home directory permissions: $HOME_PERMS"
if [ "$HOME_PERMS" = "755" ] || [ "$HOME_PERMS" = "750" ]; then
    echo -e "${GREEN}✅ Home directory permissions are secure${NC}"
else
    echo -e "${YELLOW}⚠️  Home directory permissions: $HOME_PERMS${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📋 Setup Readiness Summary${NC}"
echo "=========================="

# Generate recommendations
READY=true

if [ "$CURRENT_USER" != "ubuntu" ]; then
    echo -e "${YELLOW}• Consider switching to ubuntu user for OVH compatibility${NC}"
fi

if [ "$AVAILABLE_SPACE" -lt 200 ]; then
    echo -e "${RED}• Insufficient storage - Bitcoin blockchain requires 500GB+${NC}"
    READY=false
fi

if [ "$TOTAL_RAM" -lt 8 ]; then
    echo -e "${RED}• Insufficient RAM - Recommended 16GB+ for full stack${NC}"
    READY=false
fi

if [ ! -z "$MISSING_PACKAGES" ]; then
    echo -e "${RED}• Install missing packages: sudo apt update && sudo apt install -y$MISSING_PACKAGES${NC}"
    READY=false
fi

if [ "$READY" = true ]; then
    echo -e "\n${GREEN}🎉 Server is ready for Medampudi Family Bitcoin setup!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo "1. Download setup script: wget -O setup.sh [script-url]"
    echo "2. Edit configuration: nano setup.sh"
    echo "3. Run setup: chmod +x setup.sh && ./setup.sh"
    echo "4. Follow migration guide for Contabo data transfer"
    echo ""
    echo -e "${GREEN}🚀 You're ready to save $240/year with OVH migration!${NC}"
else
    echo -e "\n${RED}❌ Server needs configuration before Bitcoin setup${NC}"
    echo -e "${YELLOW}Fix the issues above and run this script again${NC}"
fi

echo ""
echo -e "${BLUE}💡 Support Information:${NC}"
echo "• OVH default user: ubuntu"
echo "• Required storage: 500GB+ for full node"
echo "• Required RAM: 16GB+ recommended"
echo "• Migration saves: $240/year vs Contabo"
echo ""