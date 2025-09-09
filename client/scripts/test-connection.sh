#!/bin/bash

# Test Barrier Connection Script
# Tests different connection methods to diagnose timeout issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
SERVER_IP="192.168.1.206"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier Connection Test ===${NC}"
echo "Testing connection to: $SERVER_IP"
echo

# Ensure logs directory
mkdir -p "$LOG_DIR"

echo "1. Testing basic connectivity..."
if ping -c 3 -W 5 "$SERVER_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Ping successful${NC}"
else
    echo -e "${RED}✗ Ping failed${NC}"
fi

echo
echo "2. Testing port 24800..."
if timeout 10 nc -zv "$SERVER_IP" 24800 2>&1; then
    echo -e "${GREEN}✓ Port 24800 is reachable${NC}"
else
    echo -e "${RED}✗ Port 24800 timeout or closed${NC}"
fi

echo
echo "3. Testing with SSL disabled (10 second test)..."
timeout 10s barrierc -f --no-tray --debug INFO --disable-crypto --name client "$SERVER_IP" 2>&1 | head -20 || true

echo
echo "4. Testing with SSL enabled (10 second test)..."
timeout 10s barrierc -f --no-tray --debug INFO --name client "$SERVER_IP" 2>&1 | head -20 || true

echo
echo -e "${BLUE}=== Connection Test Complete ===${NC}"
echo
echo "If both SSL tests show timeouts:"
echo "- Server might not be running or configured"
echo "- Firewall may be blocking the connection"
echo "- Network routing issues"
echo
echo "If SSL disabled works but SSL enabled fails:"
echo "- SSL certificate mismatch"
echo "- Use --disable-crypto flag"