# Barrier KVM Workflow Guide

## 🎯 Complete Workflow Management

### Current Setup Summary
- **Server**: muir (192.168.1.206)
- **Client**: client machine (right side)
- **Connection**: Seamless mouse/keyboard sharing with crypto disabled
- **Hotkeys**: Ctrl+Alt+Arrow keys for switching

---

## 🚀 Daily Workflow Patterns

### Development Workflow
**Optimal Setup:**
- **Server (muir)**: Primary development environment
  - Code editor (VS Code, Vim, etc.)
  - Terminal sessions
  - Git operations
  - Documentation

- **Client**: Testing and monitoring
  - Web browser for testing applications
  - Database management tools
  - System monitoring
  - Communication tools (Slack, email)

**Flow:**
1. Start development on server (muir)
2. Use `Ctrl+Alt+Right` to switch to client for testing
3. Copy error messages/logs from client back to server for debugging
4. Use `Ctrl+Alt+Home` for quick return to server

### Content Creation Workflow
**Optimal Setup:**
- **Server (muir)**: Primary creation tools
  - Video/image editing software
  - Writing applications
  - Design tools
  - File organization

- **Client**: Reference and preview
  - Reference materials (browser, PDFs)
  - Preview applications
  - Cloud storage management
  - Communication with collaborators

### System Administration Workflow  
**Optimal Setup:**
- **Server (muir)**: Monitoring and control
  - Terminal multiplexers (tmux/screen)
  - System monitoring dashboards
  - Log analysis tools
  - Configuration management

- **Client**: Remote systems and testing
  - SSH connections to remote servers
  - Testing environments
  - Backup verification
  - Documentation and runbooks

---

## ⌨️ Hotkey Reference

### Essential Hotkeys
| Hotkey | Action |
|--------|--------|
| `Ctrl+Alt+Left` | Switch to left screen (muir) |
| `Ctrl+Alt+Right` | Switch to right screen (client) |
| `Ctrl+Alt+Home` | Jump directly to muir (server) |
| `Ctrl+Alt+End` | Jump directly to client |

### Advanced Navigation
- **Mouse Edge**: Move mouse to right edge to switch to client
- **Clipboard**: Copy on one machine, paste on another automatically
- **Drag & Drop**: Currently not supported across machines

---

## 🔧 Optimization Strategies

### Performance Optimization
1. **Network Performance**
   - Use wired connections when possible
   - Ensure both machines on same network segment
   - Monitor network latency: `ping client-ip`

2. **Resource Management**
   - Monitor CPU/RAM usage on both machines
   - Close unnecessary background applications
   - Use lightweight alternatives when needed

3. **Display Optimization**
   - Match refresh rates between monitors
   - Use consistent DPI settings
   - Configure power management to prevent sleep

### Application Integration
1. **Synchronized Applications**
   - Use cloud storage (Dropbox, Google Drive, Nextcloud)
   - Configure SSH keys for seamless access
   - Set up shared bookmarks in browsers

2. **Consistent Environments**
   - Use same terminal emulator on both machines
   - Configure identical keyboard shortcuts
   - Sync application themes and settings

---

## 🛠️ Workflow Scripts

### Quick Environment Setup
```bash
# Run on server (muir)
./scripts/setup-workspace.sh

# This creates:
# - Workspace directories
# - Visual indicators
# - Application shortcuts
# - Monitor layout helpers
```

### Daily Startup Routine
```bash
# Check Barrier status
systemctl --user status barrier-server

# Start visual indicators
./scripts/visual-indicators.sh

# Check connection
~/.barrier/status/check-connection.sh
```

### End of Day Cleanup
```bash
# Save current session state
tmux list-sessions > ~/.barrier/session-backup.txt

# Check for any hanging processes
ps aux | grep barrier

# Optional: Stop server for maintenance
systemctl --user stop barrier-server
```

---

## 📊 Monitoring and Maintenance

### Health Checks
1. **Connection Status**
   ```bash
   ~/.barrier/status/check-connection.sh
   ```

2. **System Resources**
   ```bash
   htop
   free -h
   df -h
   ```

3. **Network Performance**
   ```bash
   iftop  # Monitor network usage
   ss -tuln | grep 24800  # Check port status
   ```

### Log Analysis
```bash
# View real-time logs
journalctl --user -u barrier-server -f

# Check for errors
journalctl --user -u barrier-server | grep ERROR

# Performance metrics
journalctl --user -u barrier-server --since "1 hour ago"
```

### Maintenance Tasks
- **Weekly**: Check for Barrier updates
- **Monthly**: Clean up log files
- **As needed**: Update configuration for new hardware
- **As needed**: Backup configuration files

---

## 🎨 User Experience Enhancements

### Visual Indicators
- **System Tray**: Shows connection status and provides quick controls
- **Desktop Widget**: Displays system info and Barrier status
- **Terminal**: Custom prompt showing connection status
- **Wallpapers**: Different backgrounds for easy machine identification

### Automation
- **Auto-start**: Barrier service starts automatically on boot
- **Health monitoring**: Automatic restart if service fails
- **Status notifications**: Desktop notifications for connection changes
- **Backup switching**: Fallback methods if primary connection fails

---

## 🔍 Common Workflows Solutions

### Problem: Frequently losing track of which machine is active
**Solution:** 
- Enable visual indicators (`./scripts/visual-indicators.sh`)
- Use different wallpapers/themes on each machine
- Configure system tray indicator

### Problem: Slow response when switching between machines
**Solution:**
- Check network performance
- Reduce `switchDelay` in barrier.conf
- Ensure both machines have adequate resources

### Problem: Applications opening on wrong machine
**Solution:**
- Use `Ctrl+Alt+Home/End` for direct machine switching
- Configure applications to remember last position
- Use workspaces/virtual desktops for organization

### Problem: Clipboard sync issues
**Solution:**
- Ensure `clipboardSharing = true` in config
- Use simple text first, then try formatted content
- Restart Barrier service if clipboard stops working

---

## 🚀 Advanced Workflows

### Multi-User Scenarios
- Create separate user accounts for different workflow types
- Use user switching for different project contexts
- Configure per-user Barrier settings

### Development Team Integration
- Share Barrier configurations via git
- Document team-specific shortcuts and workflows
- Create standardized development environments

### Backup and Recovery
- Keep multiple barrier.conf configurations
- Document hardware setup for easy recreation
- Create restoration scripts for common scenarios

---

This guide should be updated as your workflow evolves and new optimization opportunities are discovered.