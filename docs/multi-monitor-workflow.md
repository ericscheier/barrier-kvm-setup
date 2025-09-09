# Multi-Monitor Workflow Guide

## Current Setup
- **Server**: muir (left side)
- **Client**: client (right side)
- **Layout**: `muir ← → client`
- **Switching**: Move mouse to right edge or use hotkeys

## Hotkey Controls

### Quick Switching
- `Ctrl+Alt+Left Arrow`: Switch to left screen (muir)
- `Ctrl+Alt+Right Arrow`: Switch to right screen (client)
- `Ctrl+Alt+Home`: Jump directly to muir (server)
- `Ctrl+Alt+End`: Jump directly to client

## Multi-Monitor Best Practices

### Physical Setup
1. **Monitor Positioning**: Arrange monitors so the workflow feels natural
   - Server monitors on left, client monitors on right
   - Keep frequently used monitors towards the center
   - Avoid accidental switches by positioning edge monitors carefully

2. **Cable Management**: 
   - Use different colored cables for different machines
   - Label cables clearly for troubleshooting
   - Keep power and data cables organized

### Software Configuration

#### Desktop Environment Setup
```bash
# Set different wallpapers for easy identification
# Server (muir)
gsettings set org.gnome.desktop.background picture-uri 'file:///home/user/wallpapers/server-bg.jpg'

# Client 
gsettings set org.gnome.desktop.background picture-uri 'file:///home/user/wallpapers/client-bg.jpg'
```

#### Window Manager Optimization
- Use workspaces/virtual desktops on both machines
- Configure window snapping for efficient layouts
- Set up consistent application positioning

### Workflow Strategies

#### Development Workflow
- **Server (muir)**: Code editor, terminal, documentation
- **Client**: Browser for testing, communication tools, monitoring

#### Content Creation
- **Server**: Main editing application (video, graphics, writing)
- **Client**: Reference materials, preview windows, file management

#### System Administration
- **Server**: Monitoring dashboards, logs, documentation
- **Client**: Remote connections, testing environments, communication

### Application Management

#### Consistent Layouts
1. Keep similar applications in the same positions on both machines
2. Use application launchers with consistent shortcuts
3. Configure applications to remember window positions

#### Cross-Machine Integration
- Use cloud storage for shared files (Dropbox, Google Drive, etc.)
- Set up SSH keys for seamless server access
- Configure applications to sync settings where possible

## Troubleshooting Multi-Monitor Issues

### Display Detection
```bash
# Check display configuration
xrandr
# or
wayland-info
```

### Monitor Identification
- Use different themes/wallpapers for each machine
- Configure taskbar/dock differently on each system
- Use desktop widgets showing hostname/IP

### Common Issues

1. **Wrong Screen Activation**
   - Problem: Mouse goes to wrong screen
   - Solution: Check barrier.conf links section alignment

2. **Inconsistent Mouse Speed**
   - Problem: Mouse sensitivity differs between machines
   - Solution: Adjust mouse settings to match on both systems

3. **Application Window Lost**
   - Problem: Windows open on disconnected monitors
   - Solution: Use window manager tools to move windows back

### Performance Optimization

#### Network
- Use wired connections when possible
- Ensure both machines are on same network segment
- Consider Quality of Service (QoS) settings for real-time usage

#### System Resources
- Monitor CPU/RAM usage on both machines
- Close unnecessary applications
- Use lightweight desktop environments if needed

## Advanced Tips

### Script Integration
- Create scripts to launch application sets on both machines
- Use remote execution for synchronized tasks
- Implement backup switching methods

### Backup Configurations
- Keep multiple barrier.conf files for different setups
- Document monitor arrangements for easy reconfiguration
- Create restoration scripts for common scenarios