#!/bin/bash

# Family Bitcoin Services Status Dashboard
# Run this script to check the health of all family-accessible services

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for status
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"

clear
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🏠 Family Bitcoin Services Status Dashboard${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
if [ -z "$TAILSCALE_IP" ]; then
    echo -e "${RED}${CROSS} Tailscale not connected or not installed${NC}"
    TAILSCALE_IP="NOT_CONNECTED"
else
    echo -e "${GREEN}${CHECK} Tailscale connected: ${TAILSCALE_IP}${NC}"
fi

echo ""
echo -e "${CYAN}🌐 Public Services (Cloudflare Protected)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Function to check HTTP status
check_http_status() {
    local url=$1
    local name=$2
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>/dev/null)
    
    if [ "$status_code" = "200" ]; then
        echo -e "${GREEN}${CHECK} $name: Online (HTTP $status_code)${NC}"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "401" ]; then
        echo -e "${YELLOW}${WARNING} $name: Protected (HTTP $status_code - Auth Required)${NC}"
    elif [ -z "$status_code" ] || [ "$status_code" = "000" ]; then
        echo -e "${RED}${CROSS} $name: Unreachable (Connection failed)${NC}"
    else
        echo -e "${RED}${CROSS} $name: Error (HTTP $status_code)${NC}"
    fi
}

# Check public services (replace with your actual domains)
check_http_status "https://pay.yourdomain.com" "BTCPay Server"

# Note: Only BTCPay is public - all other services via Tailscale only
echo -e "${INFO} All other services are Tailscale-only (more secure)"

echo ""
echo -e "${PURPLE}🔒 Private Services (Tailscale Only)${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$TAILSCALE_IP" != "NOT_CONNECTED" ]; then
    check_http_status "http://$TAILSCALE_IP:8080" "Mempool Explorer"
    check_http_status "http://$TAILSCALE_IP:3002" "Bitcoin Explorer"
    check_http_status "http://$TAILSCALE_IP:3000" "Lightning Dashboard"
    
    # Check Electrum server ports
    echo -e "${INFO} Checking Electrum server ports..."
    if timeout 5 bash -c "</dev/tcp/$TAILSCALE_IP/50001" 2>/dev/null; then
        echo -e "${GREEN}${CHECK} Electrum TCP (50001): Available${NC}"
    else
        echo -e "${RED}${CROSS} Electrum TCP (50001): Not responding${NC}"
    fi
    
    if timeout 5 bash -c "</dev/tcp/$TAILSCALE_IP/50002" 2>/dev/null; then
        echo -e "${GREEN}${CHECK} Electrum SSL (50002): Available${NC}"
    else
        echo -e "${RED}${CROSS} Electrum SSL (50002): Not responding${NC}"
    fi
else
    echo -e "${RED}${CROSS} Cannot check private services - Tailscale not connected${NC}"
fi

echo ""
echo -e "${YELLOW}⚡ Bitcoin Node Status${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check Bitcoin node status
if command -v docker &> /dev/null; then
    if docker ps | grep -q "bitcoind"; then
        echo -e "${GREEN}${CHECK} Bitcoin Core: Container running${NC}"
        
        # Get blockchain info if bitcoin-cli is accessible
        if docker exec bitcoind bitcoin-cli getblockchaininfo &>/dev/null; then
            CHAIN_INFO=$(docker exec bitcoind bitcoin-cli getblockchaininfo 2>/dev/null)
            if [ $? -eq 0 ]; then
                BLOCKS=$(echo "$CHAIN_INFO" | grep '"blocks"' | awk '{print $2}' | sed 's/,//')
                HEADERS=$(echo "$CHAIN_INFO" | grep '"headers"' | awk '{print $2}' | sed 's/,//')
                PROGRESS=$(echo "$CHAIN_INFO" | grep '"verificationprogress"' | awk '{print $2}' | sed 's/,//')
                PROGRESS_PERCENT=$(echo "($PROGRESS * 100)" | bc -l 2>/dev/null | cut -d'.' -f1)
                
                echo -e "${INFO} Blocks: $BLOCKS / $HEADERS"
                if [ "$BLOCKS" = "$HEADERS" ]; then
                    echo -e "${GREEN}${CHECK} Sync Status: Fully synchronized${NC}"
                else
                    echo -e "${YELLOW}${WARNING} Sync Status: ${PROGRESS_PERCENT}% complete${NC}"
                fi
            fi
        fi
        
        # Check peer connections
        PEER_COUNT=$(docker exec bitcoind bitcoin-cli getpeerinfo 2>/dev/null | grep -c '"addr"' || echo "unknown")
        if [ "$PEER_COUNT" != "unknown" ]; then
            if [ "$PEER_COUNT" -gt 8 ]; then
                echo -e "${GREEN}${CHECK} Peer Connections: $PEER_COUNT${NC}"
            elif [ "$PEER_COUNT" -gt 3 ]; then
                echo -e "${YELLOW}${WARNING} Peer Connections: $PEER_COUNT (low)${NC}"
            else
                echo -e "${RED}${CROSS} Peer Connections: $PEER_COUNT (very low)${NC}"
            fi
        fi
    else
        echo -e "${RED}${CROSS} Bitcoin Core: Container not running${NC}"
    fi
else
    echo -e "${RED}${CROSS} Docker not available${NC}"
fi

echo ""
echo -e "${GREEN}📊 System Resources${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# System resources
echo -e "${INFO} CPU Cores: $(nproc)"
echo -e "${INFO} Memory Usage: $(free -h | grep Mem | awk '{print $3 " / " $2 " (" $3/$2*100 "%)"}' 2>/dev/null || echo 'Unknown')"

# Disk usage
echo -e "${INFO} Disk Usage:"
df -h | grep -E "Filesystem|/opt/bitcoin|/$" | while read line; do
    if [[ $line == *"Filesystem"* ]]; then
        continue
    fi
    usage=$(echo $line | awk '{print $(NF-1)}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        echo -e "  ${RED}${CROSS} $line${NC}"
    elif [ "$usage" -gt 75 ]; then
        echo -e "  ${YELLOW}${WARNING} $line${NC}"
    else
        echo -e "  ${GREEN}${CHECK} $line${NC}"
    fi
done

echo ""
echo -e "${CYAN}🔧 Docker Services${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command -v docker &> /dev/null; then
    # Key services to check
    SERVICES=("bitcoind" "fulcrum" "postgres" "mempool-api" "mempool-web" "btc-explorer")
    
    for service in "${SERVICES[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
            status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^$service" | awk '{print $2}')
            echo -e "${GREEN}${CHECK} $service: $status${NC}"
        else
            echo -e "${RED}${CROSS} $service: Not running${NC}"
        fi
    done
else
    echo -e "${RED}${CROSS} Docker not available${NC}"
fi

echo ""
echo -e "${BLUE}📱 Family Access Information${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$TAILSCALE_IP" != "NOT_CONNECTED" ]; then
    echo -e "${INFO} Share these with family members:"
    echo -e "  🌐 Mempool:    http://$TAILSCALE_IP:8080"
    echo -e "  🔍 Explorer:   http://$TAILSCALE_IP:3002"
    echo -e "  ⚡ Lightning: http://$TAILSCALE_IP:3000"
    echo -e "  📡 Electrum:   $TAILSCALE_IP:50001 (TCP) / $TAILSCALE_IP:50002 (SSL)"
    echo -e "  🔐 SSH:        ssh admin@$TAILSCALE_IP"
else
    echo -e "${RED}${CROSS} Tailscale not connected - family cannot access private services${NC}"
fi

echo ""
echo -e "${PURPLE}🛡️ Security Status${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Firewall status
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status | grep "Status:" | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        echo -e "${GREEN}${CHECK} Firewall: Active${NC}"
    else
        echo -e "${RED}${CROSS} Firewall: Inactive${NC}"
    fi
else
    echo -e "${YELLOW}${WARNING} UFW not installed${NC}"
fi

# Fail2ban status
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}${CHECK} Fail2ban: Active${NC}"
else
    echo -e "${YELLOW}${WARNING} Fail2ban: Not running${NC}"
fi

# Cloudflare tunnel status
if systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}${CHECK} Cloudflare Tunnel: Active${NC}"
else
    echo -e "${RED}${CROSS} Cloudflare Tunnel: Not running${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📋 Simple usage: $0 (BTCPay is only public service)${NC}"
echo -e "${BLUE}💡 Tip: Run './tailscale-family-access.sh' for family URLs${NC}"
echo -e "${BLUE}🔄 Auto-refresh: watch -n 30 $0${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"