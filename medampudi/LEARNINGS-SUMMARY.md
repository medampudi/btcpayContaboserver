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
