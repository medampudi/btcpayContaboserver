# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains comprehensive guides for Bitcoin sovereignty infrastructure:
1. **Original Setup**: Complete Bitcoin stack on Contabo server (Bitcoin Core, BTCPay Server, Lightning Network, Mempool explorer, BTC RPC Explorer, and Fulcrum Electrum server)
2. **Family Setup**: General guides for families worldwide to achieve Bitcoin financial sovereignty
3. **Business Setup**: Frappe Framework-based Bitcoin infrastructure for businesses (general and India-specific)
4. **Server Migration**: Analysis and recommendations for migrating from Contabo to OVH for better value

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
- `medampudi/complete-bitcoin-sovereignty-setup-idea.md` - Main ovhCloud deployment guide with all phases


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

### Current Server
- **Contabo VPS**: $54/month (EU hosted)
- 8 CPU cores, 32GB RAM, 1.5TB storage

### Recommended Alternatives (OVH)
- **Family Budget**: SYS-LE-1 @ ₹2,852/month ($34) - 16GB RAM, 4TB storage
- **Family Standard**: Eco-8T @ ₹3,518/month ($42) - 32GB RAM, 2TB storage  
- **Small Business**: ADVANCE-1 @ ₹8,325/month ($100) - 32GB RAM, SSD
- **Growing Business**: ADVANCE-3 @ ₹13,003/month ($156) - 128GB RAM, SSD

### Dependencies
- Docker & Docker Compose
- Tailscale VPN client
- Cloudflare account with domain
- Fail2ban for intrusion prevention
- Frappe Framework (for business setups)

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
- Family-friendly status: `/opt/bitcoin/family-status.sh`
- Backup verification: Monthly restore testing recommended

### Update Procedures
- System updates: `sudo apt update && sudo apt upgrade`
- Docker images: `docker compose pull && docker compose up -d`
- BTCPay updates: Follow BTCPay Docker upgrade process

## Family Access Management

### Tailscale Setup for Family Members
- Send invitations: `https://login.tailscale.com/admin/machines`
- Generate access info: `./rajesh/tailscale-family-access.sh`
- Family setup guide: `rajesh/tailscale-family-setup.md`
- User guide: `rajesh/family-guide.md`

### Family Service URLs (via Tailscale)
- Mempool Explorer: `http://[tailscale-ip]:8080`
- Bitcoin Explorer: `http://[tailscale-ip]:3002`
- Lightning Dashboard: `http://[tailscale-ip]:3000`
- Electrum Server: `[tailscale-ip]:50001` (TCP) or `:50002` (SSL)

## Project Files Reference

### Folder Structure
```
├── family-setup/              # General family Bitcoin sovereignty setup
│   ├── family-bitcoin-sovereignty-guide.md
│   ├── indian-family-bitcoin-guide.md
│   ├── family-bitcoin-architecture.md
│   ├── family-tax-tracker-system.md
│   └── family-bitcoin-quickstart.sh
│
├── business-setup/            # Business Bitcoin infrastructure (Frappe-based)
│   ├── frappe-bitcoin-infrastructure.md
│   ├── frappe-bitcoin-apps.md
│   ├── docker-compose-frappe.yml
│   └── frappe_bitcoin_services/
│
├── business-india/            # Indian business specific setup
│   ├── frappe-indian-bitcoin-infrastructure.md
│   ├── gst-tds-compliance.md
│   └── indian-exchange-integration.md
│
├── rajesh/                    # Contabo server-specific files
│   ├── complete-bitcoin-sovereignty-setup-idea.md
│   ├── family-guide.md
│   ├── tailscale-family-setup.md
│   ├── simple-tunnel-config.yml
│   ├── family-status.sh
│   └── tailscale-family-access.sh
│
└── (root directory)           # Server analysis and cost files
    ├── ovh-server-recommendations.md
    ├── sys-le-1-analysis.md
    ├── ovh-pricing-extracted.md
    └── infrastructure-cost-analysis.md
```

### Key Documentation

#### Original Setup
- `rajesh/complete-bitcoin-sovereignty-setup-idea.md` - Full 11-phase Contabo deployment guide
- `rajesh/family-guide.md` - User guide for family members
- `rajesh/tailscale-family-setup.md` - Tailscale setup for family access

#### Family Setups
- `family-setup/family-bitcoin-sovereignty-guide.md` - Universal family Bitcoin guide
- `family-setup/indian-family-bitcoin-guide.md` - India-specific family guide with tax compliance
- `family-setup/family-tax-tracker-system.md` - Automated tax tracking for families

#### Business Setups (Frappe Framework)
- `business-setup/frappe-bitcoin-infrastructure.md` - General business Bitcoin infrastructure
- `business-india/frappe-indian-bitcoin-infrastructure.md` - Indian business with GST/TDS compliance
- All business setups use Frappe Framework for minimal code development

#### Server Analysis (in root directory)
- `ovh-server-recommendations.md` - Detailed OVH server comparison
- `sys-le-1-analysis.md` - Specific analysis of SYS-LE-1 for family use
- `infrastructure-cost-analysis.md` - Complete cost breakdown for all setups
- `ovh-pricing-extracted.md` - Extracted pricing from OVH screenshots

### Configuration Templates
- `rajesh/simple-tunnel-config.yml` - Cloudflare Tunnel config (BTCPay only)
- `business-setup/docker-compose-frappe.yml` - Frappe + Bitcoin services

### Utility Scripts
- `rajesh/family-status.sh` - Comprehensive service health dashboard
- `rajesh/tailscale-family-access.sh` - Generate shareable access information
- `family-setup/family-bitcoin-quickstart.sh` - Universal family setup script

## Important Notes for Future Claude Sessions

### Key Decisions Made
1. **Frappe Framework**: All business applications use Frappe for minimal code development
2. **Server Recommendation**: OVH SYS-LE-1 @ ₹2,852/month ($34) is best value for families
3. **Tax Compliance**: Automated tax tracking system created for multiple jurisdictions
4. **Indian Compliance**: Specific GST/TDS handling for Indian businesses

### Cost Savings Achieved
- Current Contabo: $54/month
- Recommended OVH SYS-LE-1: $34/month  
- **Monthly Savings: $20 (37%)**
- **Annual Savings: $240**

### Project Evolution
1. Started with personal Contabo server setup
2. Expanded to general family guides (worldwide + India)
3. Added business infrastructure (Frappe-based)
4. Analyzed server costs and recommended migration to OVH

This setup prioritizes security through network isolation, minimal attack surface, and defense in depth while maintaining full Bitcoin sovereignty and self-custody capabilities. Family accessibility is integrated with security-first design, and business features leverage Frappe Framework for rapid development.