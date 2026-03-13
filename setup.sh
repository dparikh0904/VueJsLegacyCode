#!/bin/bash

# Vue Argon Design System - Setup & Run Script
# This script installs dependencies and starts the development server

set -e

echo "=========================================="
echo "  Vue Argon Design System - Setup Script"
echo "=========================================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16+ first."
    echo "   Download from: https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
echo "✓ Node.js version: $(node -v)"

if [ "$NODE_VERSION" -lt 16 ]; then
    echo "❌ Node.js version 16 or higher is required."
    echo "   Current version: $(node -v)"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

echo "✓ npm version: $(npm -v)"

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "📦 Installing dependencies..."
echo ""

# Install dependencies
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies."
    exit 1
fi

echo ""
echo "✓ Dependencies installed successfully!"
echo ""
echo "🚀 Starting development server..."
echo ""
echo "=========================================="
echo "  App will be available at:"
echo "  http://localhost:8080"
echo "=========================================="
echo ""

# Start the development server
npm run start
