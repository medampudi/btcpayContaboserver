# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a comprehensive guide for setting up a complete Bitcoin sovereignty stack on a Contabo server. The setup includes Bitcoin Core, BTCPay Server, Lightning Network, Mempool explorer, BTC RPC Explorer, and Fulcrum Electrum server with security-focused architecture.

## Architecture & Security Model

### Network Architecture
- **Public Services**: Only BTCPay Server exposed via Cloudflare Tunnel
- **Private Services**: All other services (Mempool, Explorer, Electrum, RPC) accessible only via Tailscale VPN
- **Zero Trust**: No direct SSH access - only through Tailscale network

### Service Stack
```
├── Bitcoin Core (Full Node) - Port 8333 public, RPC 8332 private
├── Fulcrum (Electrum Server) - Ports 50001/50002 private
├── BTCPay Server - HTTPS public via Cloudflare
├── Lightning Network (c-lightning + Thunderhub) - Port 3000 private
├── Mempool Explorer - Port 8080 private
├── BTC RPC Explorer - Port 3002 private
└── PostgreSQL + MariaDB - Internal only
```

### Docker Network
- Custom bridge network: 172.25.0.0/16
- Each service has static IP assignment
- Services communicate via Docker networking

## Key Configuration Files

### Primary Setup Guide
- `complete-bitcoin-sovereignty-setup-idea.md` - Main deployment guide with 11 phases

### Generated Configurations (during setup)
- `docker-compose.yml` - Main orchestration file
- `configs/fulcrum.conf` - Electrum server configuration
- `configs/mempool-config.json` - Mempool backend configuration
- `btcpay.env` - BTCPay Server environment variables

## Common Development Tasks

### Service Management
```bash
# Check status of all services
cd /opt/bitcoin && ./status.sh

# View service logs
docker logs -f [bitcoind|fulcrum|mempool-api|btcpayserver]

# Restart specific service
docker compose restart [service-name]

# Update all services
docker compose pull && docker compose up -d
```

### Bitcoin Node Operations
```bash
# Check sync status
./check-bitcoin.sh

# Bitcoin CLI commands
docker exec bitcoind bitcoin-cli -rpcuser=USER -rpcpassword=PASS [command]

# Monitor peers
docker exec bitcoind bitcoin-cli getpeerinfo | jq length
```

### Access Services
```bash
# Get Tailscale access URLs
./tailscale-services.sh

# SSH via Tailscale
ssh admin@[tailscale-ip]
```

### Backup Operations
```bash
# Manual backup
/opt/bitcoin/backup.sh

# View backup schedule
crontab -l
```

## Security Considerations

### Access Patterns
- SSH: Only via Tailscale network (100.x.x.x addresses)
- Services: Internal services only accessible through Tailscale
- Public: Only BTCPay Server via HTTPS with Cloudflare protection

### Sensitive Data Locations
- Bitcoin RPC credentials in environment variables
- Database passwords in docker-compose.yml
- SSL certificates in Fulcrum data directory
- Lightning wallet in BTCPay volumes

### Firewall Rules
- UFW blocks all incoming except: 80, 443, 8333, 9735
- Tailscale interface allowed for internal communication
- No direct RPC or database port exposure

## Infrastructure Requirements

### Minimum System Specs
- 8 CPU cores
- 32GB RAM
- 1TB+ storage
- Stable internet connection

### Dependencies
- Docker & Docker Compose
- Tailscale VPN client
- Cloudflare account with domain
- Fail2ban for intrusion prevention

## Service Dependencies

### Startup Order
1. Bitcoin Core (must sync first)
2. PostgreSQL + MariaDB
3. Fulcrum (after Bitcoin 90% synced)
4. Mempool API/Web + Explorer
5. BTCPay Server (external connection to Bitcoin)

### Critical Paths
- Bitcoin must be >50% synced before starting databases
- Fulcrum requires Bitcoin >90% synced for initial sync
- BTCPay connects to external Bitcoin node via network bridge

## Troubleshooting Guidelines

### Common Issues
- **Service won't start**: Check disk space and dependencies
- **Bitcoin sync slow**: Verify peer connections and bandwidth
- **BTCPay connection issues**: Verify external Bitcoin RPC settings
- **Tailscale access**: Ensure client connected and firewall rules

### Log Locations
- System logs: `/var/log/auth.log`, `/var/log/nginx/`
- Docker logs: `docker logs [container-name]`
- Application configs: `/opt/bitcoin/configs/`

## Monitoring & Maintenance

### Health Checks
- Automated via cron: `/opt/bitcoin/health-check.sh` (every 15 min)
- Manual status: `/opt/bitcoin/status.sh`
- Backup verification: Monthly restore testing recommended

### Update Procedures
- System updates: `sudo apt update && sudo apt upgrade`
- Docker images: `docker compose pull && docker compose up -d`
- BTCPay updates: Follow BTCPay Docker upgrade process

This setup prioritizes security through network isolation, minimal attack surface, and defense in depth while maintaining full Bitcoin sovereignty and self-custody capabilities.