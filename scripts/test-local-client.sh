#!/bin/bash

# Local Barrier Client Test Script  
# Connects to local server for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Local Barrier Client Test ===${NC}"
echo

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check if local server is running
echo "Testing local server connectivity..."
if nc -z 127.0.0.1 24800 2>/dev/null; then
    echo -e "${GREEN}✓ Local server is running on 127.0.0.1:24800${NC}"
else
    echo -e "${RED}✗ Local server not reachable${NC}"
    echo "Start the local server first: ./scripts/test-local-server.sh"
    exit 1
fi

# Kill any existing client processes
echo
echo "Stopping any existing client processes..."
killall barrierc 2>/dev/null || true
sleep 2

echo
echo -e "${GREEN}Starting barrier client (connecting to localhost)...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping client...${NC}"
    killall barrierc 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Connect to local server
barrierc \
    -f \
    --no-tray \
    --debug INFO \
    --disable-crypto \
    --name client \
    127.0.0.1 \
    2>&1 | tee "$LOG_DIR/local-client.log"