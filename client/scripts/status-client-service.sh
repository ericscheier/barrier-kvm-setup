#!/bin/bash

# Check Barrier Client Service Status
# Shows detailed status and recent logs

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier Client Service Status ===${NC}"
echo

# Show service status
systemctl --user status barrier-client.service --no-pager

echo
echo -e "${BLUE}=== Recent Logs (last 10 lines) ===${NC}"
journalctl --user -u barrier-client -n 10 --no-pager

echo
echo -e "${GREEN}For live logs: journalctl --user -u barrier-client -f${NC}"