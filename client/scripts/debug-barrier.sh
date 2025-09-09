#!/bin/bash

# Barrier Client Debug Script
# Investigates common causes of client hanging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
CONFIG_DIR="$SCRIPT_DIR/../configs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

echo "=== Barrier Client Debug Analysis ==="
echo "Timestamp: $(date)"
echo

# 1. Check current processes
echo "1. Current Barrier processes:"
ps aux | grep -E "(barrier|barrierc)" | grep -v grep || echo "No Barrier processes running"
echo

# 2. Check network connections
echo "2. Network connections on Barrier ports (24800, 24800+):"
netstat -tlnp 2>/dev/null | grep -E ":248[0-9][0-9]" || echo "No connections on Barrier ports"
echo

# 3. Check for hanging connections
echo "3. Check for ESTABLISHED connections that might be stuck:"
netstat -an | grep -E ":248[0-9][0-9].*ESTABLISHED" || echo "No established connections"
echo

# 4. Check system resources
echo "4. System load and memory:"
uptime
free -h
echo

# 5. Check for SSL certificate issues
echo "5. SSL Certificate status:"
if [ -d "$HOME/.local/share/barrier/SSL" ]; then
    ls -la "$HOME/.local/share/barrier/SSL/"
    echo "SSL directory contents:"
    find "$HOME/.local/share/barrier/SSL/" -type f -exec file {} \;
else
    echo "SSL directory not found"
fi
echo

# 6. Check X11/Wayland session
echo "6. Display session info:"
echo "DISPLAY: ${DISPLAY:-not set}"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
echo

# 7. Check for firewall issues
echo "7. Firewall status:"
sudo ufw status 2>/dev/null || echo "UFW not available or not configured"
echo

# 8. Test basic connectivity (if server IP provided)
if [ "${1:-}" ]; then
    SERVER_IP="$1"
    echo "8. Testing connectivity to server $SERVER_IP:"
    echo "Ping test:"
    ping -c 3 "$SERVER_IP" || echo "Ping failed"
    echo
    echo "Port connectivity test (port 24800):"
    nc -zv "$SERVER_IP" 24800 2>&1 || echo "Port 24800 not reachable"
    echo
fi

echo "=== Debug analysis complete ==="
echo "Logs saved to: $LOG_DIR/debug-$(date +%Y%m%d-%H%M%S).log"