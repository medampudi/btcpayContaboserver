#!/bin/bash
# Fix the Bitcoin Core version in docker-compose.yml

echo "🔧 Fixing Bitcoin Core Docker image version..."

# Change Bitcoin version from 27.0 to 26.0 (latest stable)
sed -i 's/btcpayserver\/bitcoin:27.0/btcpayserver\/bitcoin:26.0/g' /opt/bitcoin/docker-compose.yml

echo "✅ Fixed! Using Bitcoin Core 26.0 (latest stable)"

# Restart the setup
echo "🚀 Starting Bitcoin Core with correct version..."
cd /opt/bitcoin
docker compose up -d bitcoind

# Check if it started
sleep 10
if docker ps | grep -q bitcoind; then
    echo "✅ Bitcoin Core started successfully!"
    docker logs bitcoind --tail 20
else
    echo "❌ Bitcoin Core failed to start. Checking available versions..."
    docker pull btcpayserver/bitcoin:latest
fi