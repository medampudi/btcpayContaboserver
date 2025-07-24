#!/bin/bash
# Archive old scripts for reference

echo "Archiving old scripts..."

# Create archive directory
mkdir -p old-scripts-archive

# Move all old scripts except the main ones
mv bitcoin-sovereignty-setup.sh old-scripts-archive/ 2>/dev/null
mv bitcoin-sovereignty-setup-fixed.sh old-scripts-archive/ 2>/dev/null
mv bitcoin-setup-simple.sh old-scripts-archive/ 2>/dev/null
mv setup-bitcoin-node.sh old-scripts-archive/ 2>/dev/null
mv test-config.sh old-scripts-archive/ 2>/dev/null
mv create-monitoring-scripts.sh old-scripts-archive/ 2>/dev/null
mv continue-setup.sh old-scripts-archive/ 2>/dev/null
mv fix-and-continue.sh old-scripts-archive/ 2>/dev/null
mv fix-scripts.sh old-scripts-archive/ 2>/dev/null

# Keep the working scripts
echo "Keeping essential scripts:"
echo "- bitcoin-complete-setup.sh (main consolidated script)"
echo "- setup-config.env (your configuration)"
echo "- check-sync.sh (sync checker)"
echo "- complete-bitcoin-setup.sh (phase 2 after sync)"
echo "- quick-fix-continue.sh (the one that worked)"

echo ""
echo "Old scripts archived in: old-scripts-archive/"
echo "You can safely delete this directory if not needed."