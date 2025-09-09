#!/bin/bash

# Configure firewall for Barrier server

set -euo pipefail

echo "Configuring firewall for Barrier server"

# Check if UFW is installed and active
if command -v ufw >/dev/null 2>&1; then
    echo "UFW detected. Adding rule for Barrier port 24800..."
    echo "Run: sudo ufw allow 24800/tcp"
    echo ""
fi

# Check if firewalld is running
if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "firewalld detected. Adding rule for Barrier port 24800..."
    echo "Run: sudo firewall-cmd --permanent --add-port=24800/tcp"
    echo "Run: sudo firewall-cmd --reload"
    echo ""
fi

# Check if iptables is available
if command -v iptables >/dev/null 2>&1; then
    echo "iptables available. Manual rule for Barrier port 24800:"
    echo "Run: sudo iptables -A INPUT -p tcp --dport 24800 -j ACCEPT"
    echo ""
fi

echo "Barrier uses port 24800/tcp for client connections"
echo "Make sure this port is open in your firewall configuration"