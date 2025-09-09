#!/bin/bash

# Comprehensive Barrier Testing Script
# Tests local setup and network connectivity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
NETWORK_SERVER="192.168.1.206"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier Comprehensive Test Suite ===${NC}"
echo

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Test 1: Basic Installation Check
echo -e "${BLUE}1. Testing Barrier Installation${NC}"
if command -v barriers >/dev/null 2>&1 && command -v barrierc >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Barrier installed: server $(which barriers), client $(which barrierc)${NC}"
else
    echo -e "${RED}✗ Barrier not properly installed${NC}"
    exit 1
fi

# Test 2: Local Server Configuration Test
echo
echo -e "${BLUE}2. Testing Local Server Configuration${NC}"
LOCAL_CONFIG="$PROJECT_DIR/server/barrier.conf"
if [ -f "$LOCAL_CONFIG" ]; then
    echo -e "${GREEN}✓ Server config found${NC}"
    echo "Configuration preview:"
    head -15 "$LOCAL_CONFIG" | sed 's/^/  /'
else
    echo -e "${RED}✗ Server config missing${NC}"
fi

# Test 3: Network Connectivity Test
echo
echo -e "${BLUE}3. Testing Network Connectivity to $NETWORK_SERVER${NC}"

# Ping test
if ping -c 2 -W 3 "$NETWORK_SERVER" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Network ping successful${NC}"
else
    echo -e "${YELLOW}⚠ Network ping failed${NC}"
fi

# Port test
if timeout 5 nc -z "$NETWORK_SERVER" 24800 2>/dev/null; then
    echo -e "${GREEN}✓ Port 24800 reachable on network server${NC}"
    NETWORK_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ Port 24800 not reachable on network server${NC}"
    NETWORK_AVAILABLE=false
fi

# Test 4: Local Connection Test
echo
echo -e "${BLUE}4. Starting Local Server Test${NC}"
echo "This test will:"
echo "  • Start a local Barrier server on 127.0.0.1:24800"
echo "  • Test client connection to local server"
echo "  • Verify configuration compatibility"
echo

read -p "Press Enter to start local server test (or Ctrl+C to skip)..."

# Start local server in background
echo "Starting local server..."
"$SCRIPT_DIR/test-local-server.sh" > "$LOG_DIR/local-server-test.log" 2>&1 &
LOCAL_SERVER_PID=$!

# Give server time to start
sleep 3

# Test local connection
echo "Testing local client connection..."
if timeout 10 nc -z 127.0.0.1 24800 2>/dev/null; then
    echo -e "${GREEN}✓ Local server started successfully${NC}"
    
    # Quick client test
    echo "Testing client connection (5 seconds)..."
    timeout 5 "$SCRIPT_DIR/test-local-client.sh" > "$LOG_DIR/local-client-test.log" 2>&1 || true
    
    # Check logs for success indicators
    if grep -q "connected to server" "$LOG_DIR/local-client-test.log" 2>/dev/null; then
        echo -e "${GREEN}✓ Local client connection successful!${NC}"
        LOCAL_TEST_SUCCESS=true
    else
        echo -e "${YELLOW}⚠ Local client connection had issues${NC}"
        echo "Check logs: $LOG_DIR/local-client-test.log"
        LOCAL_TEST_SUCCESS=false
    fi
else
    echo -e "${RED}✗ Local server failed to start${NC}"
    LOCAL_TEST_SUCCESS=false
fi

# Clean up local server
echo "Stopping local server..."
kill $LOCAL_SERVER_PID 2>/dev/null || true
killall barriers barrierc 2>/dev/null || true
sleep 2

# Test 5: Network Server Connection Test
if [ "$NETWORK_AVAILABLE" = true ]; then
    echo
    echo -e "${BLUE}5. Testing Network Server Connection${NC}"
    echo "Testing connection to real server at $NETWORK_SERVER..."
    
    read -p "Press Enter to test network connection (or Ctrl+C to skip)..."
    
    echo "Testing network client connection (10 seconds)..."
    timeout 10 barrierc -f --no-tray --debug INFO --disable-crypto --name client "$NETWORK_SERVER" \
        > "$LOG_DIR/network-client-test.log" 2>&1 || true
    
    if grep -q "connected to server" "$LOG_DIR/network-client-test.log" 2>/dev/null; then
        echo -e "${GREEN}✓ Network server connection successful!${NC}"
        NETWORK_TEST_SUCCESS=true
    elif grep -q "disconnected from server" "$LOG_DIR/network-client-test.log" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Network server connects but disconnects immediately${NC}"
        echo "This usually means server needs --disable-crypto flag too"
        NETWORK_TEST_SUCCESS=false
    else
        echo -e "${RED}✗ Network server connection failed${NC}"
        NETWORK_TEST_SUCCESS=false
    fi
else
    echo
    echo -e "${YELLOW}5. Skipping Network Test (server not reachable)${NC}"
    NETWORK_TEST_SUCCESS=false
fi

# Summary
echo
echo -e "${BLUE}=== Test Results Summary ===${NC}"
echo
[ "$LOCAL_TEST_SUCCESS" = true ] && echo -e "${GREEN}✓ Local test: PASSED${NC}" || echo -e "${YELLOW}⚠ Local test: Issues detected${NC}"
[ "$NETWORK_AVAILABLE" = true ] && {
    [ "$NETWORK_TEST_SUCCESS" = true ] && echo -e "${GREEN}✓ Network test: PASSED${NC}" || echo -e "${YELLOW}⚠ Network test: Server config needs update${NC}"
} || echo -e "${YELLOW}⚠ Network test: SKIPPED (server unavailable)${NC}"

echo
echo "📋 Log files created:"
echo "  • Local server: $LOG_DIR/local-server-test.log"
echo "  • Local client: $LOG_DIR/local-client-test.log" 
[ "$NETWORK_AVAILABLE" = true ] && echo "  • Network client: $LOG_DIR/network-client-test.log"

echo
if [ "$NETWORK_AVAILABLE" = true ] && [ "$NETWORK_TEST_SUCCESS" = false ]; then
    echo -e "${BLUE}💡 Next Steps:${NC}"
    echo "The network server at $NETWORK_SERVER needs to run with --disable-crypto:"
    echo "  barriers -f --no-tray --debug INFO --disable-crypto --name muir --config ~/.barrier/barrier.conf"
fi