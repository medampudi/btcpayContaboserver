# Family Bitcoin Services Guide

## 🏠 Welcome to Our Family Bitcoin Stack

This guide helps you access and use our private Bitcoin infrastructure. All services run on our own server, giving us complete control and privacy.

## 📱 Available Services

### 📊 Mempool Explorer
**Purpose**: View Bitcoin network status, transaction fees, and mempool activity
**What you can do**:
- Check current network fees before sending Bitcoin
- Track transaction confirmations in real-time
- See network congestion and recommended fees
- Explore recent blocks and transactions

**Access**: `http://[tailscale-ip]:8080` (Tailscale required)

### 🔍 Bitcoin Explorer (BTC RPC Explorer)
**Purpose**: Detailed Bitcoin blockchain explorer and analysis tool
**What you can do**:
- Look up any Bitcoin address, transaction, or block
- View detailed transaction information and scripts
- Check address balances and transaction history
- Analyze network statistics and mining data

**Access**: `http://[tailscale-ip]:3002` (Tailscale required)

### ⚡ Lightning Dashboard (Thunderhub)
**Purpose**: Lightning Network node management interface
**What you can do**:
- View our Lightning node status and channels
- See Lightning Network statistics
- Monitor channel balances and routing
- Track Lightning payments and receipts

**Access**: `http://[tailscale-ip]:3000` (Tailscale required)

### 💳 BTCPay Server
**Purpose**: Bitcoin payment processing and invoice creation
**What you can do**:
- Create Bitcoin invoices for payments
- Accept Bitcoin payments with Lightning support
- Track payment status and confirmations
- Generate QR codes for easy payments

**Access**: `https://pay.yourdomain.com`

## 🔌 Connecting Your Bitcoin Wallet

### Option 1: Electrum Wallet (Recommended)
Electrum is a lightweight Bitcoin wallet that can connect directly to our node:

**Setup Steps**:
1. Download Electrum from [electrum.org](https://electrum.org)
2. Install and create/restore your wallet
3. Go to **Tools** → **Network** 
4. **Uncheck** "Select server automatically"
5. **Manual server configuration**:
   - **Server**: `[YOUR_TAILSCALE_IP]` or your domain
   - **Port**: `50001` (TCP) or `50002` (SSL)
   - **Protocol**: TCP or SSL
6. Click **OK** and wait for connection

**Benefits**:
- ✅ Your transactions are private (don't go through third parties)
- ✅ Faster transaction broadcasting
- ✅ Full SPV verification against our node
- ✅ No reliance on external Electrum servers

### Option 2: Other SPV Wallets
Many wallets support custom Electrum servers:
- **Sparrow Wallet**: Professional desktop wallet
- **Blue Wallet**: Mobile wallet with Electrum support
- **Specter Desktop**: Advanced wallet with hardware wallet support

## 🔐 Security & Privacy Benefits

### What This Gives Our Family:
- **🏠 Full Node Privacy**: Our transactions don't leak to third parties
- **⚡ Lightning Ready**: Instant, low-fee payments within family
- **🔍 Complete Transparency**: Verify all Bitcoin activity ourselves
- **🛡️ No KYC/AML**: Private financial sovereignty
- **📊 Real Data**: Accurate fee estimates and network info
- **🎯 Self-Custody**: Your keys, your Bitcoin, our infrastructure

### Privacy Protection:
- All wallet connections are encrypted
- No transaction data shared with external services
- Your Bitcoin addresses remain private
- Our node doesn't log personal information

## 🚀 Getting Started

### For Beginners:
1. **Start with Mempool Explorer** to understand Bitcoin fees
2. **Use BTCPay** to receive your first Bitcoin payment
3. **Set up Electrum** when ready for a proper wallet

### For Advanced Users:
1. **Connect hardware wallets** to Electrum via our server
2. **Use Lightning Dashboard** to understand channel management
3. **Explore BTC RPC Explorer** for detailed blockchain analysis

## 📞 Family Support

### Common Issues:
- **Can't connect to Electrum server**: Check Tailscale connection
- **Authentication problems**: Clear browser cookies, try incognito
- **Slow loading**: Network congestion, try again in a few minutes

### Getting Help:
- Check service status with family admin
- Ask questions in family chat
- Review Bitcoin basics at [bitcoin.org](https://bitcoin.org)

## 🔧 Technical Details

### Network Information:
- **Bitcoin Network**: Mainnet (real Bitcoin)
- **Node Software**: Bitcoin Core v26.0
- **Electrum Server**: Fulcrum
- **Lightning**: c-lightning
- **Security**: Tailscale VPN + Cloudflare protection

### Connection Details:
- **Electrum Server**: `[tailscale-ip]:50001` (TCP) / `[tailscale-ip]:50002` (SSL)
- **Bitcoin RPC**: Available for advanced users (ask admin)
- **Lightning**: Family Lightning node with multiple channels

## 🎯 Family Bitcoin Goals

This infrastructure helps us achieve:
- **Financial sovereignty** through self-custody
- **Privacy protection** from surveillance
- **Educational opportunities** to learn Bitcoin
- **Cost savings** through Lightning Network
- **Network support** by running a full node
- **Emergency preparedness** with our own infrastructure

---

**Remember**: This is real Bitcoin on the main network. Always double-check addresses and amounts before sending transactions. When in doubt, ask family members for help!

**Your Bitcoin, Your Node, Your Rules** 🧡