# Client Integration Guide

## ✅ Server Status: READY FOR CLIENT TESTING

### Server Configuration
- **Host**: muir (192.168.1.206)
- **Port**: 24800 (firewall configured)
- **Status**: Active and tested with client connections
- **Crypto**: Disabled for compatibility
- **Layout**: `muir ← → client`

### Repository
**GitHub**: https://github.com/ericscheier/barrier-kvm-setup
- All code committed and pushed
- Production-ready configuration
- Comprehensive documentation
- Management scripts included

---

## Client Developer Instructions

### 1. Clone Repository
```bash
git clone https://github.com/ericscheier/barrier-kvm-setup.git
cd barrier-kvm-setup
```

### 2. Client Setup
```bash
# Activate environment (if using flox)
flox activate

# Run client setup
./client/scripts/setup-client.sh

# Start client with correct settings
barrierc -f --no-tray --debug INFO --disable-crypto --name client 192.168.1.206
```

### 3. Expected Behavior
- **Mouse movement**: Move mouse to LEFT edge to switch to server
- **Screen layout**: `client ← → muir`
- **Connection**: Should connect immediately without SSL errors
- **Switching**: Smooth transitions between machines

---

## Configuration Details

### Server Settings (Already Applied)
```
Server IP: 192.168.1.206:24800
Crypto: Disabled (--disable-crypto flag)
Screen Name: muir
Client Name: client
Layout: muir on left, client on right
```

### Client Command
```bash
barrierc -f --no-tray --debug INFO --disable-crypto --name client 192.168.1.206
```

---

## Testing Checklist

- [ ] Client connects without SSL/crypto errors
- [ ] Mouse movement switches screens smoothly
- [ ] Keyboard input follows mouse cursor
- [ ] Copy/paste works between machines
- [ ] No hanging or disconnection issues

---

## Available Resources

### Documentation
- `client/docs/troubleshooting.md` - Client-specific troubleshooting
- `docs/workflow-guide.md` - Complete workflow strategies
- `docs/multi-monitor-workflow.md` - Multi-monitor best practices

### Scripts
- `client/scripts/start-client.sh` - Standard client startup
- `client/scripts/debug-barrier.sh` - Connection debugging
- `client/scripts/test-connection.sh` - Network connectivity test
- `client/scripts/monitor-client.sh` - Health monitoring

### Management Tools
- `scripts/config-manager.sh` - Switch between configurations
- `scripts/visual-indicators.sh` - UI enhancements
- `scripts/system-backup.sh` - Backup/restore functionality

---

## Support

If issues arise:
1. Check `client/docs/troubleshooting.md`
2. Run `./client/scripts/debug-barrier.sh 192.168.1.206`
3. Check server logs: `journalctl --user -u barrier-server -f`
4. Review configuration with `./scripts/config-manager.sh current`

**Server is ready and waiting for client connection!** 🚀