#!/bin/bash
# ======================================================================
# CasinoR — VPS Deployment Script
# Run this script on your Ubuntu VPS to deploy the full stack.
# ======================================================================

set -e

echo "🚀 Starting CasinoR Deployment..."

# 1. Check for Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable docker
    sudo systemctl start docker
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true
fi

# 2. Build the Flutter Web Client (assuming Flutter is installed)
# (Skipped: We are only testing the native Flutter app)

# 3. Spin up the Production Stack
echo "Starting Docker Compose (Production)..."
cd infrastructure
docker-compose -f docker-compose.prod.yml up -d --build

echo ""
echo "✅ Deployment Successful!"
echo "Your application is now running. Nginx is listening on port 80."
echo "Since the frontend dynamically routes to relative APIs, you can visit:"
echo "http://<YOUR_VPS_IP>/"
echo ""
echo "To view logs: docker compose -f docker-compose.prod.yml logs -f"
