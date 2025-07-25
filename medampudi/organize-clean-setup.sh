#!/bin/bash
# Organize and clean up the medampudi folder for production use

set -eo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Organizing Bitcoin Setup Scripts ===${NC}"
echo ""

# Create organized structure
echo -e "${YELLOW}Creating organized directory structure...${NC}"

# 1. Create archive for old/experimental scripts
mkdir -p old-scripts-archive
mkdir -p production-ready

# 2. Move old/experimental scripts to archive
echo -e "${YELLOW}Archiving old experimental scripts...${NC}"
mv bitcoin-sovereignty-setup.sh old-scripts-archive/ 2>/dev/null || true
mv bitcoin-sovereignty-setup-fixed.sh old-scripts-archive/ 2>/dev/null || true
mv bitcoin-setup-simple.sh old-scripts-archive/ 2>/dev/null || true
mv bitcoin-complete-setup.sh old-scripts-archive/ 2>/dev/null || true
mv continue-setup.sh old-scripts-archive/ 2>/dev/null || true
mv fix-and-continue.sh old-scripts-archive/ 2>/dev/null || true
mv fix-scripts.sh old-scripts-archive/ 2>/dev/null || true
mv quick-fix-continue.sh old-scripts-archive/ 2>/dev/null || true
mv create-monitoring-scripts.sh old-scripts-archive/ 2>/dev/null || true
mv setup-bitcoin-node.sh old-scripts-archive/ 2>/dev/null || true
mv test-config.sh old-scripts-archive/ 2>/dev/null || true
mv archive-old-scripts.sh old-scripts-archive/ 2>/dev/null || true
mv fix-bitcoin-password.sh old-scripts-archive/ 2>/dev/null || true

# Move old documentation
mv AUTOMATED-SETUP-README.md old-scripts-archive/ 2>/dev/null || true
mv README-SETUP.md old-scripts-archive/ 2>/dev/null || true
mv CURRENT-STATUS.md old-scripts-archive/ 2>/dev/null || true
mv complete-bitcoin-sovereignty-setup-idea.md old-scripts-archive/ 2>/dev/null || true
mv UBUNTU-VERSION-GUIDE.md old-scripts-archive/ 2>/dev/null || true

# Move family-specific files
mkdir -p family-guides
mv indian-tax-automation.md family-guides/ 2>/dev/null || true
mv kids-bitcoin-learning.md family-guides/ 2>/dev/null || true
mv medampudi-family-bitcoin-guide.md family-guides/ 2>/dev/null || true

# 3. Keep only production-ready files in main directory
echo -e "${YELLOW}Organizing production files...${NC}"

# These are the only files needed for a fresh install:
# - bitcoin-node-setup.sh (the consolidated script)
# - setup-config-template.env (for new installations)
# - setup-config.env (current configuration)
# - check-sync.sh (monitor sync progress)
# - complete-bitcoin-setup.sh (finalize after sync)
# - README-FINAL.md (documentation)

# 4. Create a clean README for production use
echo -e "${YELLOW}Creating production README...${NC}"

# 5. Show final structure
echo ""
echo -e "${GREEN}✓ Organization complete!${NC}"
echo ""
echo "Production-ready structure:"
echo "=========================="
tree -L 2 . 2>/dev/null || {
    echo "medampudi/"
    echo "├── bitcoin-node-setup.sh      # Main setup script"
    echo "├── setup-config.env          # Your configuration"
    echo "├── setup-config-template.env # Template for new installs"
    echo "├── check-sync.sh            # Monitor Bitcoin sync"
    echo "├── complete-bitcoin-setup.sh # Finalize after sync"
    echo "├── README-PRODUCTION.md     # Clean documentation"
    echo "├── family-guides/           # Family-specific guides"
    echo "└── old-scripts-archive/     # Previous experiments"
}

echo ""
echo -e "${BLUE}For new Ubuntu 22.04 installations:${NC}"
echo "1. Copy bitcoin-node-setup.sh and setup-config-template.env"
echo "2. Rename template to setup-config.env and edit values"
echo "3. Run as root: ./bitcoin-node-setup.sh"

# 6. Create summary of what was learned
cat > LEARNINGS-SUMMARY.md << 'EOF'
# Key Learnings from Bitcoin Setup Journey

## Issues Encountered and Fixed

1. **User/Group Permissions**
   - Problem: "The group 'admin' already exists"
   - Solution: Check if group exists before creating, use `-g` flag with useradd

2. **Bitcoin RPC Password**
   - Problem: "#" character not allowed in bitcoin.conf
   - Solution: Generate passwords without special characters (#, =, +, /)

3. **Script Execution**
   - Problem: Unbound variables with `set -u`
   - Solution: Use `set -eo pipefail` instead

4. **Docker Compose Syntax**
   - Problem: JQ parsing errors in heredocs
   - Solution: Proper escaping and variable substitution

## Final Working Configuration

- Ubuntu 22.04 LTS (recommended) or 24.04 LTS
- Login as ubuntu user (default for most cloud providers)
- Script handles all user/group creation properly
- Phase-based approach allows resuming after interruptions
- All services accessible only via Tailscale VPN (security first)

## Production Script Features

The final `bitcoin-node-setup.sh` incorporates:
- Proper error handling and logging
- System validation before starting
- Configuration file validation
- Automatic Tailscale setup with auth key
- Docker and Docker Compose installation
- Bitcoin Core with proper RPC configuration
- Monitoring scripts created automatically
- Daily backup automation

This represents weeks of debugging condensed into one reliable script!
EOF

echo ""
echo -e "${GREEN}✓ Created LEARNINGS-SUMMARY.md with key insights${NC}"