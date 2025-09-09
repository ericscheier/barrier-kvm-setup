# Barrier Client Auto-Start Guide

The Barrier client can be configured to start automatically when you boot your machine using two methods:

## Method 1: Systemd User Service (Recommended)

### Installation
```bash
# Install and enable the service
./client/scripts/install-client-service.sh

# Note: You may be prompted for sudo password to enable user lingering
```

### Management Commands
```bash
# Start the service
./client/scripts/start-client-service.sh
# OR: systemctl --user start barrier-client

# Stop the service  
./client/scripts/stop-client-service.sh
# OR: systemctl --user stop barrier-client

# Check status and logs
./client/scripts/status-client-service.sh
# OR: systemctl --user status barrier-client

# View live logs
journalctl --user -u barrier-client -f

# Restart the service
systemctl --user restart barrier-client
```

### Benefits
- ✅ Automatic startup on boot
- ✅ Auto-restart if client crashes
- ✅ Full logging via systemd journal
- ✅ Standard service management
- ✅ Works without desktop session

## Method 2: Desktop Autostart (Backup)

A desktop autostart entry is also configured at:
`~/.config/autostart/barrier-client.desktop`

This provides a fallback method that starts the client when your desktop session begins.

## Service Configuration

The systemd service is configured with:
- **Auto-restart**: If the client crashes, it restarts after 5 seconds
- **Logging**: All output goes to systemd journal
- **Environment**: DISPLAY=:0 is set automatically
- **Target**: Starts with the graphical session

## Troubleshooting

### Service Won't Start
```bash
# Check service status
systemctl --user status barrier-client

# View recent logs
journalctl --user -u barrier-client -n 20

# Manually test the command
/usr/bin/barrierc -f --no-tray --debug INFO --disable-crypto --name client 192.168.1.206
```

### Service Starts But Doesn't Connect
- Ensure server at 192.168.1.206 is running
- Check network connectivity: `ping 192.168.1.206`
- Test port connectivity: `nc -zv 192.168.1.206 24800`

### Multiple Clients Running
```bash
# Stop all barrier processes
killall barrierc

# Start only the service
systemctl --user start barrier-client
```

## File Locations

- **Service file**: `~/.config/systemd/user/barrier-client.service`
- **Autostart file**: `~/.config/autostart/barrier-client.desktop`
- **Management scripts**: `./client/scripts/*-service.sh`

## Current Status

After installation, the barrier client will:
- ✅ Start automatically on every boot
- ✅ Reconnect automatically if server restarts
- ✅ Restart automatically if it crashes
- ✅ Work seamlessly in the background

You can reboot your machine and the barrier client will be ready immediately after login!