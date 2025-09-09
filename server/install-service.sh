#!/bin/bash

# Install Barrier server as a systemd user service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER=$(whoami)

echo "Installing Barrier server service for user $USER"

# Create systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Copy service file
cp "$SCRIPT_DIR/barrier-server.service" ~/.config/systemd/user/

# Reload systemd and enable the service
systemctl --user daemon-reload
systemctl --user enable barrier-server.service

echo "Barrier server service installed and enabled"
echo ""
echo "To start the service:"
echo "  systemctl --user start barrier-server"
echo ""
echo "To check status:"
echo "  systemctl --user status barrier-server"
echo ""
echo "To view logs:"
echo "  journalctl --user -u barrier-server -f"