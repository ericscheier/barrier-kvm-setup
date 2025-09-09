# Barrier Client Troubleshooting

## Common Client Hanging Issues

### 1. SSL Certificate Problems
**Symptoms**: Client connects briefly then hangs or disconnects
**Cause**: Missing, invalid, or mismatched SSL certificates
**Solutions**:
- Regenerate SSL certificates on server
- Copy server certificates to client
- Use `--disable-crypto` for testing (not recommended for production)

### 2. Network Configuration Issues
**Symptoms**: Client hangs during connection attempt
**Cause**: Firewall blocking ports, network timeout issues
**Solutions**:
- Ensure port 24800 is open on both machines
- Check for NAT/router issues
- Test with `nc -zv server_ip 24800`
- Disable firewall temporarily for testing

### 3. Display Server Problems
**Symptoms**: Client starts but input doesn't work or causes hanging
**Cause**: X11/Wayland permission issues, wrong DISPLAY variable
**Solutions**:
- Ensure DISPLAY is set correctly (usually :0)
- For Wayland: may need X11 compatibility mode
- Check `xhost +local:` for X11 permissions

### 4. Process/Resource Issues
**Symptoms**: Client becomes unresponsive after working initially
**Cause**: Memory leaks, file descriptor limits, zombie processes
**Solutions**:
- Kill and restart client regularly
- Monitor with `htop` and `lsof`
- Check system logs for resource exhaustion

### 5. Version Incompatibility
**Symptoms**: Connection fails or behaves unpredictably
**Cause**: Server and client running different Barrier versions
**Solutions**:
- Ensure same version on both machines
- Check with `barrier --version`

## Debug Steps

1. **Check processes**: `ps aux | grep barrier`
2. **Check connections**: `netstat -tlnp | grep 24800`
3. **Test connectivity**: `nc -zv server_ip 24800`
4. **Check logs**: Look in `~/.local/share/barrier/` or use `--log` flag
5. **Monitor resources**: `htop`, `free -h`, `uptime`
6. **Check display**: `echo $DISPLAY`, `xdpyinfo`

## Known Working Configuration

- Ubuntu 20.04+ with X11 session
- Barrier 2.4.0+ on both client and server
- Port 24800 open in both directions
- SSL disabled for initial testing
- Client started with: `barrierc -f --no-tray --debug INFO --name client-hostname server-ip`