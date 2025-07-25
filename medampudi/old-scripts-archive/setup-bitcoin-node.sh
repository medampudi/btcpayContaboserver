#!/bin/bash
# =============================================================================
# Bitcoin Node Setup Wrapper
# This script loads configuration and runs the main setup
# =============================================================================

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Bitcoin Sovereignty Node Setup ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Please run: sudo ./setup-bitcoin-node.sh"
   exit 1
fi

# Check for config file
CONFIG_FILE="setup-config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}"
    echo ""
    echo "Please:"
    echo "1. Copy setup-config.env.example to setup-config.env"
    echo "2. Edit setup-config.env with your values"
    echo "3. Run this script again"
    exit 1
fi

# Load configuration
echo -e "${BLUE}Loading configuration...${NC}"
source "$CONFIG_FILE"

# Basic validation
echo -e "${BLUE}Validating configuration...${NC}"

ERRORS=0

# Check critical variables
if [[ "$DOMAIN_NAME" == "your-domain.com" ]] || [[ -z "$DOMAIN_NAME" ]]; then
    echo -e "${RED}✗ DOMAIN_NAME not configured${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Domain: $DOMAIN_NAME${NC}"
fi

if [[ "$EMAIL" == "your-email@gmail.com" ]] || [[ -z "$EMAIL" ]]; then
    echo -e "${RED}✗ EMAIL not configured${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Email: $EMAIL${NC}"
fi

if [[ "$BITCOIN_RPC_PASS" == "CHANGE_THIS_StrongPassword123!@#" ]]; then
    echo -e "${RED}✗ BITCOIN_RPC_PASS still has default value${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Bitcoin RPC password configured${NC}"
fi

if [[ "$POSTGRES_PASS" == "CHANGE_THIS_PostgresPassword456!@#" ]]; then
    echo -e "${RED}✗ POSTGRES_PASS still has default value${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ PostgreSQL password configured${NC}"
fi

if [[ -z "$TAILSCALE_AUTHKEY" ]]; then
    echo -e "${YELLOW}⚠ TAILSCALE_AUTHKEY not provided (manual setup required)${NC}"
else
    echo -e "${GREEN}✓ Tailscale auth key provided${NC}"
fi

if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
    echo -e "${YELLOW}⚠ Cloudflare API not configured (manual tunnel setup required)${NC}"
else
    echo -e "${GREEN}✓ Cloudflare API configured${NC}"
fi

echo ""

# Exit if critical errors
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Please fix the $ERRORS error(s) above in $CONFIG_FILE${NC}"
    exit 1
fi

# Show configuration summary
echo -e "${BLUE}=== Configuration Summary ===${NC}"
echo "Domain: $DOMAIN_NAME"
echo "BTCPay: $BTCPAY_DOMAIN"
echo "Family: $FAMILY_NAME"
echo "Server: $(hostname) → $SERVER_HOSTNAME"
echo "Timezone: $TIMEZONE"
echo "RAM for Bitcoin: ${BITCOIN_DBCACHE}MB"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}This will set up a complete Bitcoin node infrastructure.${NC}"
echo -e "${YELLOW}The process will take 30-45 minutes plus sync time.${NC}"
echo ""
read -p "Continue with setup? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Export all variables for the main script
export DOMAIN_NAME BTCPAY_DOMAIN EMAIL FAMILY_NAME
export SERVER_HOSTNAME SWAP_SIZE TIMEZONE CURRENCY_DISPLAY
export SSH_PORT ADMIN_USER
export BITCOIN_RPC_USER BITCOIN_RPC_PASS
export POSTGRES_PASS MARIADB_ROOT_PASS MARIADB_MEMPOOL_PASS
export TAILSCALE_AUTHKEY CLOUDFLARE_API_TOKEN CLOUDFLARE_ZONE_ID CLOUDFLARE_ACCOUNT_ID
export BITCOIN_MAX_CONNECTIONS BITCOIN_DBCACHE BITCOIN_MAXMEMPOOL
export FAMILY_MEMBERS SKIP_BITCOIN_SYNC ENABLE_TOR ENABLE_I2P

# Check if main setup script exists
SETUP_SCRIPT="bitcoin-setup-simple.sh"
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    # Try other versions
    if [[ -f "bitcoin-sovereignty-setup-fixed.sh" ]]; then
        SETUP_SCRIPT="bitcoin-sovereignty-setup-fixed.sh"
    elif [[ -f "bitcoin-sovereignty-setup.sh" ]]; then
        SETUP_SCRIPT="bitcoin-sovereignty-setup.sh"
    else
        echo -e "${RED}Main setup script not found${NC}"
        echo "Please ensure all files are present."
        exit 1
    fi
fi

# Make sure it's executable
chmod +x "$SETUP_SCRIPT"

# Run the main setup
echo ""
echo -e "${GREEN}Starting Bitcoin sovereignty setup...${NC}"
echo ""

./"$SETUP_SCRIPT"