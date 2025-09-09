#!/bin/bash

# Barrier KVM Server Setup Script
# This script sets up Barrier as a server on Linux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME=$(hostname)
LOCAL_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')

echo "Setting up Barrier server on $HOSTNAME ($LOCAL_IP)"

# Check if Barrier is installed
if ! command -v barriers &> /dev/null; then
    echo "Barrier not found. Installing via apt..."
    sudo apt-get update
    sudo apt-get install -y barrier
fi

# Create Barrier configuration directory
mkdir -p ~/.barrier

# Copy configuration file
cp "$SCRIPT_DIR/barrier.conf" ~/.barrier/barrier.conf

echo "Barrier server configuration created at ~/.barrier/barrier.conf"
echo "Server hostname: $HOSTNAME"
echo "Server IP: $LOCAL_IP"
echo ""
echo "To start the server manually:"
echo "  barriers -f --no-tray --debug INFO --name $HOSTNAME --config ~/.barrier/barrier.conf"
echo ""
echo "Configure your client to connect to: $LOCAL_IP:24800"