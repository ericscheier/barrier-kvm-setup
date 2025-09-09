#!/bin/bash

# Barrier KVM Setup - Unified Server/Client Setup
# Detects role and runs appropriate setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier KVM Setup ===${NC}"
echo

# Check if we should run as server or client
if [ "${1:-}" == "server" ]; then
    ROLE="server"
elif [ "${1:-}" == "client" ]; then
    ROLE="client"  
else
    echo "Please specify role:"
    echo "  ./setup.sh server   - Setup as Barrier server"
    echo "  ./setup.sh client   - Setup as Barrier client"
    echo
    exit 1
fi

echo -e "${GREEN}Setting up as: $ROLE${NC}"
echo

# Activate flox environment if available
if [ -f "$SCRIPT_DIR/.flox/env/manifest.toml" ] && command -v flox >/dev/null 2>&1; then
    echo "Activating flox environment..."
    # Note: This script should be run within flox activate
    if [ -z "${FLOX_ENV:-}" ]; then
        echo -e "${YELLOW}Warning: Not in flox environment. Run 'flox activate' first.${NC}"
    fi
fi

# Run role-specific setup
case $ROLE in
    "server")
        echo -e "${BLUE}Running server setup...${NC}"
        cd "$SCRIPT_DIR"
        ./server/setup.sh
        echo
        echo -e "${GREEN}Server setup complete!${NC}"
        echo
        echo "Next steps:"
        echo "1. Configure firewall: ./server/configure-firewall.sh"
        echo "2. Install service: ./server/install-service.sh"
        echo "3. Start server: barriers -f --no-tray --debug INFO --name \$(hostname) --config ~/.barrier/barrier.conf"
        ;;
    "client")
        echo -e "${BLUE}Running client setup...${NC}"
        cd "$SCRIPT_DIR"
        ./client/scripts/setup-client.sh
        echo
        echo -e "${GREEN}Client setup complete!${NC}"
        echo
        echo "Next steps:"
        echo "1. Start client: ./client/scripts/start-client.sh"
        echo "2. For monitoring: ./client/scripts/monitor-client.sh"
        echo "3. For debugging: ./client/scripts/debug-barrier.sh 192.168.1.206"
        ;;
esac

echo
echo -e "${BLUE}Setup completed for $ROLE mode!${NC}"