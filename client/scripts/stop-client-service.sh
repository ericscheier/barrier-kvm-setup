#!/bin/bash

# Stop Barrier Client Service
# Stops the systemd user service

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Stopping Barrier Client Service ===${NC}"
echo

# Stop the service
systemctl --user stop barrier-client.service

echo -e "${GREEN}✓ Service stopped${NC}"
echo

# Show status
systemctl --user status barrier-client.service --no-pager || true