#!/bin/bash

# Barrier Client Startup Script
# Starts the client with proper configuration and monitoring

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

# Load configuration
if [ ! -f "$CONFIG_DIR/client.conf" ]; then
    echo -e "${RED}Error: Client configuration not found. Run ./scripts/setup-client.sh first.${NC}"
    exit 1
fi

# Source the config file (convert to bash variables)
SERVER_IP=$(grep "server_ip=" "$CONFIG_DIR/client.conf" | cut -d'=' -f2)
CLIENT_NAME=$(grep "client_name=" "$CONFIG_DIR/client.conf" | cut -d'=' -f2 | envsubst)
LOG_FILE="$LOG_DIR/client.log"

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: Server IP not configured. Run ./scripts/setup-client.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}=== Starting Barrier Client ===${NC}"
echo "Server: $SERVER_IP"
echo "Client: $CLIENT_NAME"
echo "Log: $LOG_FILE"
echo

# Kill any existing client processes
echo "Stopping any existing barrier processes..."
killall barrierc barrier 2>/dev/null || true
sleep 2

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start the client with robust configuration
echo -e "${GREEN}Starting barrier client...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo

# Use a function to handle cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Stopping barrier client...${NC}"
    killall barrierc 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start client with server-provided parameters
# Note: Using server dev's exact command format
barrierc \
    -f \
    --no-tray \
    --debug INFO \
    --name "$CLIENT_NAME" \
    "$SERVER_IP" \
    2>&1 | tee -a "$LOG_FILE"