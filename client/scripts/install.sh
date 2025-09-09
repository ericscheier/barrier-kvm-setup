#!/bin/bash

# Barrier Installation and Environment Setup Script
# Ensures barrier is installed and flox environment is configured

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Barrier Environment Installation ===${NC}"
echo

# Check if we're in the project directory
if [ ! -f "$PROJECT_DIR/.flox/env/manifest.toml" ]; then
    echo -e "${RED}Error: Must be run from barrier project directory${NC}"
    exit 1
fi

# Install system dependencies if needed
echo "Checking system dependencies..."

# Check if barrier is installed
if ! command -v barrierc >/dev/null 2>&1; then
    echo -e "${YELLOW}Barrier not found. Installing via apt...${NC}"
    
    # Check if we can use apt
    if command -v apt-get >/dev/null 2>&1; then
        echo "Updating package lists..."
        sudo apt-get update
        
        echo "Installing barrier..."
        sudo apt-get install -y barrier
        
        echo -e "${GREEN}✓ Barrier installed successfully${NC}"
    else
        echo -e "${RED}Error: apt-get not available. Please install barrier manually:${NC}"
        echo "  - On Debian/Ubuntu: sudo apt-get install barrier"
        echo "  - On Fedora: sudo dnf install barrier"
        echo "  - On Arch: sudo pacman -S barrier"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Barrier already installed: $(which barrierc)${NC}"
fi

# Install flox dependencies
echo
echo "Setting up flox environment..."

cd "$PROJECT_DIR"

# Check if flox is available
if ! command -v flox >/dev/null 2>&1; then
    echo -e "${RED}Error: flox not found. Please install flox first:${NC}"
    echo "  curl -1sLf 'https://dl.floxdev.com/public/flox/setup.deb.sh' | sudo -E bash"
    echo "  sudo apt install flox"
    exit 1
fi

# Install flox dependencies
echo "Installing flox packages..."
flox install

echo
echo -e "${GREEN}✓ Environment setup complete!${NC}"

# Verify installation
echo
echo "Verifying installation..."
echo -e "${BLUE}Barrier version:${NC} $(barrierc --version 2>&1 | head -1)"

if command -v netcat >/dev/null 2>&1; then
    echo -e "${GREEN}✓ netcat available${NC}"
fi

if command -v nmap >/dev/null 2>&1; then
    echo -e "${GREEN}✓ nmap available${NC}"
fi

echo
echo -e "${GREEN}=== Installation complete! ===${NC}"
echo
echo "Next steps:"
echo "1. Run: ./scripts/setup-client.sh"
echo "2. Configure your server IP"
echo "3. Start client: ./scripts/start-client.sh"
echo
echo -e "${YELLOW}Note: Make sure to activate the flox environment with 'flox activate' before running other scripts.${NC}"