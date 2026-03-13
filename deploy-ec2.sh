#!/bin/bash

# Vue Argon Design System - EC2 Deployment Script
# Run this script on a fresh EC2 instance (Amazon Linux 2 or Ubuntu)

set -e

echo "=========================================="
echo "  EC2 Deployment Script"
echo "=========================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS"

# Install Node.js 20.x
echo ""
echo "📦 Installing Node.js 20.x..."

if [ "$OS" = "amzn" ] || [ "$OS" = "rhel" ] || [ "$OS" = "centos" ]; then
    # Amazon Linux / RHEL / CentOS
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
    sudo yum install -y nodejs git
elif [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    # Ubuntu / Debian
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs git
else
    echo "❌ Unsupported OS: $OS"
    echo "   Supported: Amazon Linux, Ubuntu, Debian, RHEL, CentOS"
    exit 1
fi

echo "✓ Node.js version: $(node -v)"
echo "✓ npm version: $(npm -v)"

# Clone the repository (if not already in the project directory)
REPO_URL="https://github.com/dparikh0904/VueJsLegacyCode.git"
APP_DIR="$HOME/VueJsLegacyCode"

if [ ! -d "$APP_DIR" ]; then
    echo ""
    echo "📥 Cloning repository..."
    git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Install PM2 for process management
echo ""
echo "📦 Installing PM2 process manager..."
sudo npm install -g pm2

# Build for production (optional - for serving static files)
echo ""
echo "🔨 Building for production..."
npm run build

# Install serve for static file serving
sudo npm install -g serve

# Start with PM2
echo ""
echo "🚀 Starting application with PM2..."

# Stop existing instance if running
pm2 delete vue-argon 2>/dev/null || true

# Option 1: Serve production build (recommended for production)
pm2 start "serve -s dist -l 8080" --name vue-argon

# Option 2: Run dev server (uncomment below, comment above)
# pm2 start npm --name vue-argon -- run start

# Save PM2 config to restart on reboot
pm2 save
pm2 startup | tail -1 | sudo bash

echo ""
echo "=========================================="
echo "  ✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "  App running at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'YOUR_EC2_PUBLIC_IP'):8080"
echo ""
echo "  Useful commands:"
echo "    pm2 status        - Check app status"
echo "    pm2 logs vue-argon - View logs"
echo "    pm2 restart vue-argon - Restart app"
echo "    pm2 stop vue-argon - Stop app"
echo ""
echo "  ⚠️  Make sure port 8080 is open in your EC2 Security Group!"
echo "=========================================="
