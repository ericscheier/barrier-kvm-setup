# Barrier KVM Comprehensive Troubleshooting Guide

## 🔧 Quick Diagnostic Commands

### First Steps - Run These Always
```bash
# 1. Check service status
systemctl --user status barrier-server

# 2. Check connection
~/.barrier/status/check-connection.sh

# 3. View recent logs
journalctl --user -u barrier-server --since "10 minutes ago"

# 4. Test network connectivity
ping -c 3 192.168.1.206  # Replace with actual client IP
```

---

## 🚨 Common Issues & Solutions

### 1. Server Won't Start

**Symptoms:**
- Service fails to start
- "Address already in use" errors
- Permission denied errors

**Diagnosis:**
```bash
# Check what's using port 24800
ss -tlnp | grep 24800

# Check for old processes
ps aux | grep barrier

# Check configuration syntax
barriers --config ~/.barrier/barrier.conf --check-config
```

**Solutions:**
```bash
# Kill existing processes
pkill -f barriers

# Reset systemd service
systemctl --user daemon-reload
systemctl --user restart barrier-server

# Check file permissions
ls -la ~/.barrier/barrier.conf
chmod 644 ~/.barrier/barrier.conf
```

### 2. Client Cannot Connect

**Symptoms:**
- Client hangs during connection
- "Connection refused" errors
- Client connects then immediately disconnects

**Diagnosis:**
```bash
# Test network connectivity from client
nc -zv 192.168.1.206 24800

# Check firewall on server
sudo ufw status
# or
sudo firewall-cmd --list-ports

# Check if server is listening
netstat -tlnp | grep 24800
```

**Solutions:**
```bash
# Open firewall port (choose your firewall)
sudo ufw allow 24800/tcp
# or
sudo firewall-cmd --permanent --add-port=24800/tcp && sudo firewall-cmd --reload

# Restart network service
sudo systemctl restart NetworkManager

# Try disabling crypto temporarily (already done in our setup)
# --disable-crypto flag is already in the service
```

### 3. Mouse/Keyboard Input Not Working

**Symptoms:**
- Mouse moves but clicks don't register
- Keyboard input goes to wrong machine
- Input lag or missed keystrokes

**Diagnosis:**
```bash
# Check display environment
echo $DISPLAY
echo $XDG_SESSION_TYPE

# Check input devices
xinput list

# Check for competing applications
ps aux | grep -E "(synergy|input|kvm)"
```

**Solutions:**
```bash
# Fix display variable
export DISPLAY=:0

# For Wayland sessions
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

# Restart display manager (careful - will log you out)
sudo systemctl restart gdm3  # or lightdm, sddm

# Check X11 permissions
xhost +local:
```

### 4. Clipboard Not Syncing

**Symptoms:**
- Copy/paste doesn't work between machines
- Only text syncs, not formatted content
- Clipboard works intermittently

**Diagnosis:**
```bash
# Check clipboard tools
which xclip xsel

# Test clipboard manually
echo "test" | xclip -selection clipboard
xclip -selection clipboard -o

# Check barrier config
grep -i clipboard ~/.barrier/barrier.conf
```

**Solutions:**
```bash
# Install clipboard utilities
sudo apt-get install xclip xsel

# Restart barrier with clipboard debugging
systemctl --user stop barrier-server
barriers -f --no-tray --debug DEBUG --name muir --config ~/.barrier/barrier.conf

# Check barrier.conf has clipboard enabled
# (Already configured in our enhanced version)
```

### 5. Hotkeys Not Working

**Symptoms:**
- Ctrl+Alt+Arrow keys don't switch screens
- Hotkeys work sometimes but not always
- Wrong screen activation

**Diagnosis:**
```bash
# Check configuration syntax
grep -A 10 "keystroke" ~/.barrier/barrier.conf

# Test if keys are captured by other applications
xev  # Then press Ctrl+Alt+Arrow and see if events are captured
```

**Solutions:**
```bash
# Stop the server service
systemctl --user stop barrier-server

# Test configuration manually
barriers -f --no-tray --debug DEBUG --name muir --config ~/.barrier/barrier.conf

# Check for conflicting shortcuts in desktop environment
# GNOME: Settings > Keyboard > Shortcuts
# KDE: System Settings > Shortcuts
```

### 6. Performance Issues

**Symptoms:**
- Laggy mouse movement
- Delayed keyboard input
- High CPU usage
- Network timeouts

**Diagnosis:**
```bash
# Check system resources
htop
iotop
iftop

# Check network latency
ping -c 100 192.168.1.206 | tail -5

# Monitor barrier process
top -p $(pgrep barriers)
```

**Solutions:**
```bash
# Optimize network settings in barrier.conf
# (Already configured with heartbeat = 5000)

# Reduce CPU usage
systemctl --user edit barrier-server
# Add:
# [Service]
# Nice=5
# CPUQuota=50%

# Use wired connection instead of WiFi
# Ensure both machines on same network segment
# Check QoS settings on router
```

---

## 🔍 Advanced Troubleshooting

### Debug Mode Operation
```bash
# Stop regular service
systemctl --user stop barrier-server

# Start in debug mode
barriers -f --no-tray --debug DEBUG --name muir --config ~/.barrier/barrier.conf

# In another terminal, watch logs
tail -f ~/.local/share/barrier/barriers.log
```

### Network Debugging
```bash
# Capture network traffic
sudo tcpdump -i any port 24800

# Monitor connections
watch 'ss -tuln | grep 24800'

# Test different ports
barriers -f --no-tray --debug INFO --address :24801 --name muir --config ~/.barrier/barrier.conf
```

### Configuration Testing
```bash
# Validate configuration syntax
barriers --config ~/.barrier/barrier.conf --check-config

# Test minimal configuration
cat > /tmp/minimal.conf << 'EOF'
section: screens
    muir:
    client:
end
section: links
    muir:
        right = client
    client:
        left = muir
end
EOF

barriers -f --no-tray --debug INFO --config /tmp/minimal.conf
```

---

## 🛡️ Security Troubleshooting

### SSL/TLS Issues (When Crypto Enabled)
```bash
# Generate new certificates
mkdir -p ~/.local/share/barrier/SSL
openssl req -x509 -nodes -days 365 -subj /CN=Barrier -newkey rsa:2048 \
    -keyout ~/.local/share/barrier/SSL/Barrier.pem \
    -out ~/.local/share/barrier/SSL/Barrier.pem

# Copy to client
scp ~/.local/share/barrier/SSL/Barrier.pem client:~/.local/share/barrier/SSL/
```

### Permission Issues
```bash
# Fix barrier directory permissions
chmod -R 755 ~/.barrier
chmod 644 ~/.barrier/barrier.conf

# Fix systemd service permissions
chmod 644 ~/.config/systemd/user/barrier-server.service
systemctl --user daemon-reload
```

---

## 📋 Systematic Diagnosis Procedure

### Step 1: Environment Check
```bash
echo "=== Environment Check ==="
echo "Hostname: $(hostname)"
echo "IP Address: $(ip route get 1.1.1.1 | grep -oP 'src \K\S+')"
echo "Display: $DISPLAY"
echo "Session Type: $XDG_SESSION_TYPE"
echo "Desktop: $XDG_CURRENT_DESKTOP"
```

### Step 2: Service Status
```bash
echo "=== Service Status ==="
systemctl --user is-active barrier-server
systemctl --user is-enabled barrier-server
systemctl --user status barrier-server --no-pager
```

### Step 3: Network Check
```bash
echo "=== Network Check ==="
ss -tlnp | grep 24800
ping -c 3 192.168.1.206  # Replace with actual client IP
nc -zv 192.168.1.206 24800
```

### Step 4: Configuration Validation
```bash
echo "=== Configuration Check ==="
test -f ~/.barrier/barrier.conf && echo "Config exists" || echo "Config missing"
barriers --config ~/.barrier/barrier.conf --check-config
```

### Step 5: Resource Check
```bash
echo "=== Resource Check ==="
free -h
df -h ~/.barrier
ps aux | grep barrier
```

---

## 🔄 Recovery Procedures

### Complete Reset
```bash
# Stop all barrier processes
systemctl --user stop barrier-server
pkill -f barrier

# Backup current config
cp ~/.barrier/barrier.conf ~/.barrier/barrier.conf.backup.$(date +%Y%m%d)

# Reset to default configuration
./setup.sh server

# Restart service
systemctl --user daemon-reload
systemctl --user start barrier-server
```

### Emergency Fallback
```bash
# If systemd service fails, manual start
barriers -f --no-tray --debug INFO --disable-crypto --name muir \
    --config ~/.barrier/barrier.conf

# If config is corrupted, use minimal config
barriers -f --no-tray --debug INFO --disable-crypto --name muir \
    --config /tmp/minimal.conf
```

### Log Collection for Support
```bash
# Collect all relevant logs and info
mkdir -p /tmp/barrier-debug
journalctl --user -u barrier-server > /tmp/barrier-debug/systemd.log
cp ~/.barrier/barrier.conf /tmp/barrier-debug/
cp ~/.config/systemd/user/barrier-server.service /tmp/barrier-debug/
dmesg | grep -i barrier > /tmp/barrier-debug/dmesg.log
lshw -short > /tmp/barrier-debug/hardware.txt
ip addr > /tmp/barrier-debug/network.txt

# Create archive
tar -czf barrier-debug-$(date +%Y%m%d-%H%M).tar.gz /tmp/barrier-debug/
```

---

## 🎯 Prevention Best Practices

### Regular Maintenance
- Monitor logs weekly: `journalctl --user -u barrier-server --since "1 week ago" | grep ERROR`
- Check for updates monthly: `apt list --upgradable | grep barrier`
- Backup configurations before changes
- Test hotkeys after system updates

### Monitoring Setup
```bash
# Add to crontab for automated health checks
crontab -e
# Add this line:
# */15 * * * * ~/.barrier/status/check-connection.sh > /tmp/barrier-health.log 2>&1
```

### Documentation
- Keep a change log of configuration modifications
- Document any custom networking or firewall rules
- Note which hardware combinations work best
- Record successful troubleshooting procedures