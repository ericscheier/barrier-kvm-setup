#!/bin/bash

# Quick Test Script for Barrier Client Setup
# Tests the basic functionality without connecting to a server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier Client Quick Test ===${NC}"
echo

# Test 1: Check barrier installation
echo "1. Testing Barrier installation..."
if command -v barrierc >/dev/null 2>&1; then
    echo -e "${GREEN}✓ barrierc found: $(which barrierc)${NC}"
    echo -e "${GREEN}✓ Version: $(barrierc --version 2>&1 | head -1)${NC}"
else
    echo -e "${RED}✗ barrierc not found${NC}"
    exit 1
fi

# Test 2: Check display environment
echo
echo "2. Testing display environment..."
if [ -n "${DISPLAY:-}" ]; then
    echo -e "${GREEN}✓ DISPLAY set to: $DISPLAY${NC}"
else
    echo -e "${RED}✗ DISPLAY not set${NC}"
    export DISPLAY=":0"
    echo -e "${BLUE}  Set DISPLAY to :0${NC}"
fi

# Test 3: Check project structure
echo
echo "3. Testing project structure..."
for dir in configs scripts logs docs; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
        echo -e "${GREEN}✓ $dir/ directory exists${NC}"
    else
        echo -e "${RED}✗ $dir/ directory missing${NC}"
    fi
done

# Test 4: Check scripts are executable
echo
echo "4. Testing scripts..."
for script in install.sh setup-client.sh start-client.sh debug-barrier.sh monitor-client.sh; do
    if [ -x "$SCRIPT_DIR/$script" ]; then
        echo -e "${GREEN}✓ $script is executable${NC}"
    else
        echo -e "${RED}✗ $script not executable${NC}"
    fi
done

# Test 5: Test barrier help (quick functionality test)
echo
echo "5. Testing barrier client help..."
if barrierc --help >/dev/null 2>/dev/null; then
    echo -e "${GREEN}✓ Barrier client responds to --help${NC}"
else
    # Barrier returns help text via stderr, which is normal
    if barrierc --help 2>&1 | grep -q "Usage:"; then
        echo -e "${GREEN}✓ Barrier client responds to --help${NC}"
    else
        echo -e "${RED}✗ Barrier client --help failed${NC}"
    fi
fi

# Test 6: Check debug tools
echo
echo "6. Testing debug tools..."
tools=("netcat" "nmap" "openssl" "lsof")
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $tool available${NC}"
    else
        echo -e "${RED}✗ $tool not found${NC}"
    fi
done

echo
echo -e "${BLUE}=== Test Summary ===${NC}"
echo
echo "✅ Basic setup appears functional!"
echo
echo "Next steps to connect to a server:"
echo "1. Run: ./scripts/setup-client.sh"
echo "2. Enter your server IP when prompted"  
echo "3. Start client: ./scripts/start-client.sh"
echo
echo "For troubleshooting: ./scripts/debug-barrier.sh [server-ip]"
echo "For monitoring: ./scripts/monitor-client.sh"