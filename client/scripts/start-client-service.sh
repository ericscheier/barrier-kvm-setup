#!/bin/bash

# Start Barrier Client Service
# Starts the systemd user service

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Starting Barrier Client Service ===${NC}"
echo

# Start the service
systemctl --user start barrier-client.service

echo -e "${GREEN}✓ Service started${NC}"
echo

# Show status
systemctl --user status barrier-client.service --no-pager

echo
echo "To view live logs: journalctl --user -u barrier-client -f"