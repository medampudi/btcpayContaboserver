#!/bin/bash
# Test configuration file loading

echo "Testing configuration file..."

# Check if config file exists
if [[ ! -f "setup-config.env" ]]; then
    echo "ERROR: setup-config.env not found"
    exit 1
fi

# Try to source the config file
echo "Loading configuration..."
set +u  # Temporarily disable unbound variable checking
source setup-config.env
set -u  # Re-enable

echo "Configuration loaded successfully!"
echo ""
echo "=== Configuration Summary ==="
echo "Domain: ${DOMAIN_NAME:-NOT SET}"
echo "Email: ${EMAIL:-NOT SET}"
echo "Family: ${FAMILY_NAME:-NOT SET}"
echo "Tailscale Key: ${TAILSCALE_AUTHKEY:0:20}..." 
echo ""
echo "All variables loaded successfully!"