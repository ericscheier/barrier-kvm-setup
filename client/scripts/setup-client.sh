#!/bin/bash

# Barrier Client Setup Script
# Configures the client for reliable operation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configs"
LOG_DIR="$PROJECT_DIR/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Barrier Client Setup ===${NC}"
echo

# Check if running with flox
if [ -z "${FLOX_ENV:-}" ]; then
    echo -e "${YELLOW}Warning: Not running in flox environment. Run 'flox activate' first.${NC}"
    echo
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p "$LOG_DIR"
mkdir -p "$HOME/.local/share/barrier/SSL"

# Check for existing barrier installation
echo "Checking Barrier installation..."
if ! command -v barrierc >/dev/null 2>&1; then
    echo -e "${RED}Error: barrierc not found. Please install barrier:${NC}"
    echo "sudo apt-get update && sudo apt-get install barrier"
    exit 1
fi

echo -e "${GREEN}✓ Barrier client found: $(which barrierc)${NC}"

# Get barrier version
BARRIER_VERSION=$(barrierc --version 2>&1 | head -1 || echo "Unknown version")
echo -e "${GREEN}✓ Version: $BARRIER_VERSION${NC}"

# Configure client
echo
echo "Configuring client..."

# Ask for server IP if not already configured
if [ ! -f "$CONFIG_DIR/server_ip" ]; then
    echo -n "Enter Barrier server IP address: "
    read -r SERVER_IP
    echo "$SERVER_IP" > "$CONFIG_DIR/server_ip"
    echo -e "${GREEN}✓ Server IP saved: $SERVER_IP${NC}"
else
    SERVER_IP=$(cat "$CONFIG_DIR/server_ip")
    echo -e "${GREEN}✓ Using saved server IP: $SERVER_IP${NC}"
fi

# Update client configuration
sed -i "s/server_ip=.*/server_ip=$SERVER_IP/" "$CONFIG_DIR/client.conf"

# Test connectivity
echo
echo "Testing connectivity to server..."
if nc -z -w5 "$SERVER_IP" 24800; then
    echo -e "${GREEN}✓ Server is reachable on port 24800${NC}"
else
    echo -e "${YELLOW}⚠ Cannot reach server on port 24800${NC}"
    echo "  This might be normal if the server isn't running yet."
fi

# Check X11 session
echo
echo "Checking display environment..."
if [ -n "${DISPLAY:-}" ]; then
    echo -e "${GREEN}✓ DISPLAY set to: $DISPLAY${NC}"
    if command -v xdpyinfo >/dev/null 2>&1; then
        if xdpyinfo >/dev/null 2>&1; then
            echo -e "${GREEN}✓ X11 display accessible${NC}"
        else
            echo -e "${YELLOW}⚠ X11 display not accessible${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ DISPLAY not set${NC}"
    export DISPLAY=":0"
    echo -e "${BLUE}  Setting DISPLAY to :0${NC}"
fi

# Check for SSL certificates
echo
echo "Checking SSL configuration..."
if [ -d "$HOME/.local/share/barrier/SSL" ] && [ "$(ls -A "$HOME/.local/share/barrier/SSL" 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ SSL certificates found${NC}"
    ls -la "$HOME/.local/share/barrier/SSL/"
else
    echo -e "${YELLOW}⚠ No SSL certificates found${NC}"
    echo -e "${BLUE}  Will use non-encrypted connection for initial setup${NC}"
fi

echo
echo -e "${GREEN}=== Client setup complete! ===${NC}"
echo
echo "Next steps:"
echo "1. Start the server on $SERVER_IP"
echo "2. Run: ./scripts/start-client.sh"
echo "3. Check logs in: $LOG_DIR/"
echo
echo "For troubleshooting, run: ./scripts/debug-barrier.sh $SERVER_IP"