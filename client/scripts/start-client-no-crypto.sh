#!/bin/bash

# Barrier Client Startup Script (No Crypto)
# Starts the client without SSL encryption to avoid certificate issues

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

# Load server IP and client name
SERVER_IP=$(grep "server_ip=" "$CONFIG_DIR/client.conf" | cut -d'=' -f2)
CLIENT_NAME=$(grep "client_name=" "$CONFIG_DIR/client.conf" | cut -d'=' -f2)
LOG_FILE="$LOG_DIR/client-no-crypto.log"

echo -e "${BLUE}=== Starting Barrier Client (No Crypto) ===${NC}"
echo "Server: $SERVER_IP"
echo "Client: $CLIENT_NAME"
echo "Log: $LOG_FILE"
echo -e "${YELLOW}Note: SSL encryption disabled for testing${NC}"
echo

# Kill any existing client processes
echo "Stopping any existing barrier processes..."
killall barrierc barrier 2>/dev/null || true
sleep 2

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start the client with SSL disabled
echo -e "${GREEN}Starting barrier client (no crypto)...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping barrier client...${NC}"
    killall barrierc 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start client with SSL disabled
barrierc \
    -f \
    --no-tray \
    --debug INFO \
    --disable-crypto \
    --name "$CLIENT_NAME" \
    "$SERVER_IP" \
    2>&1 | tee -a "$LOG_FILE"