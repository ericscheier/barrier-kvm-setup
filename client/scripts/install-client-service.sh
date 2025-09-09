#!/bin/bash

# Install Barrier Client Service
# Sets up systemd user service for automatic startup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installing Barrier Client Service ===${NC}"
echo

# Check if service file exists
SERVICE_FILE="$HOME/.config/systemd/user/barrier-client.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo -e "${RED}Error: Service file not found at $SERVICE_FILE${NC}"
    echo "The service file should have been created automatically."
    exit 1
fi

echo -e "${GREEN}✓ Service file found${NC}"

# Reload systemd user services
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# Enable the service
echo "Enabling barrier-client service..."
systemctl --user enable barrier-client.service

# Enable user lingering (allows user services to start at boot)
echo "Enabling user lingering..."
sudo loginctl enable-linger "$USER"

echo
echo -e "${GREEN}=== Service Installation Complete! ===${NC}"
echo
echo "Service status:"
systemctl --user status barrier-client.service --no-pager || true
echo
echo "Available commands:"
echo "  Start service:   systemctl --user start barrier-client"
echo "  Stop service:    systemctl --user stop barrier-client"
echo "  Restart service: systemctl --user restart barrier-client"
echo "  Check status:    systemctl --user status barrier-client"
echo "  View logs:       journalctl --user -u barrier-client -f"
echo
echo "The service will now start automatically on boot!"