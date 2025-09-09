#!/bin/bash

# Local Barrier Server Test Script
# Starts a local Barrier server for testing client connectivity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
SERVER_CONFIG="$PROJECT_DIR/server/barrier.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Local Barrier Server Test ===${NC}"
echo

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check if server config exists
if [ ! -f "$SERVER_CONFIG" ]; then
    echo -e "${RED}Error: Server config not found at $SERVER_CONFIG${NC}"
    exit 1
fi

# Check if barrier server is available
if ! command -v barriers >/dev/null 2>&1; then
    echo -e "${RED}Error: barriers command not found. Install barrier first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Barrier server available: $(which barriers)${NC}"
echo -e "${GREEN}✓ Using config: $SERVER_CONFIG${NC}"

# Kill any existing barrier processes
echo
echo "Stopping any existing barrier processes..."
killall barriers barrierc 2>/dev/null || true
sleep 2

# Create a local test config with current hostname
HOSTNAME=$(hostname)
LOCAL_CONFIG="$LOG_DIR/test-server.conf"
sed "s/muir/$HOSTNAME/g" "$SERVER_CONFIG" > "$LOCAL_CONFIG"

# Show the configuration we're using
echo
echo -e "${BLUE}Server configuration:${NC}"
cat "$LOCAL_CONFIG"
echo

# Start local server without crypto for testing
echo -e "${GREEN}Starting local barrier server (no crypto)...${NC}"
echo -e "${YELLOW}Server will run on localhost:24800${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping local server...${NC}"
    killall barriers 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start server with debug output (let it bind to all interfaces)
barriers \
    -f \
    --no-tray \
    --debug INFO \
    --disable-crypto \
    --name "$(hostname)" \
    --config "$LOCAL_CONFIG" \
    2>&1 | tee "$LOG_DIR/local-server.log"