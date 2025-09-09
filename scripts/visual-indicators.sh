#!/bin/bash

# Visual Indicators Script for Barrier KVM
# Creates visual cues to distinguish between server and client machines

set -euo pipefail

HOSTNAME=$(hostname)
BARRIER_DIR="$HOME/.barrier"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🎨 Barrier Visual Indicators Setup${NC}"
    echo "=================================="
    echo "Hostname: $HOSTNAME"
    echo ""
}

# Function to create desktop notification
show_notification() {
    local title="$1"
    local message="$2"
    local icon="${3:-dialog-information}"
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" --icon="$icon" --urgency=low
    fi
}

# Function to create system tray indicator
create_tray_indicator() {
    echo -e "${BLUE}📍 Creating system tray indicator...${NC}"
    
    local indicator_dir="$BARRIER_DIR/indicators"
    mkdir -p "$indicator_dir"
    
    # Create a simple Python tray indicator
    cat > "$indicator_dir/barrier-tray.py" << 'EOF'
#!/usr/bin/env python3
"""
Barrier KVM System Tray Indicator
Shows current machine role and connection status
"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3, GObject
import subprocess
import socket
import os
import time
import threading

class BarrierIndicator:
    def __init__(self):
        self.hostname = socket.gethostname()
        self.indicator = AppIndicator3.Indicator.new(
            "barrier-kvm",
            "network-workgroup",
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.build_menu())
        self.update_status()
        
        # Start status monitoring thread
        self.monitor_thread = threading.Thread(target=self.monitor_status, daemon=True)
        self.monitor_thread.start()

    def build_menu(self):
        menu = Gtk.Menu()
        
        # Hostname item
        hostname_item = Gtk.MenuItem(f"Host: {self.hostname}")
        hostname_item.set_sensitive(False)
        menu.append(hostname_item)
        
        menu.append(Gtk.SeparatorMenuItem())
        
        # Status item
        self.status_item = Gtk.MenuItem("Status: Checking...")
        self.status_item.set_sensitive(False)
        menu.append(self.status_item)
        
        menu.append(Gtk.SeparatorMenuItem())
        
        # Control items
        restart_item = Gtk.MenuItem("Restart Server")
        restart_item.connect('activate', self.restart_server)
        menu.append(restart_item)
        
        logs_item = Gtk.MenuItem("View Logs")
        logs_item.connect('activate', self.view_logs)
        menu.append(logs_item)
        
        menu.append(Gtk.SeparatorMenuItem())
        
        # Quit item
        quit_item = Gtk.MenuItem("Quit Indicator")
        quit_item.connect('activate', self.quit)
        menu.append(quit_item)
        
        menu.show_all()
        return menu

    def update_status(self):
        try:
            # Check if barriers process is running
            result = subprocess.run(['pgrep', 'barriers'], capture_output=True)
            if result.returncode == 0:
                self.status_item.set_label("Status: Server Running ✅")
                self.indicator.set_icon("network-workgroup")
            else:
                self.status_item.set_label("Status: Server Stopped ❌")
                self.indicator.set_icon("network-offline")
        except Exception as e:
            self.status_item.set_label(f"Status: Error - {str(e)}")
            
    def monitor_status(self):
        while True:
            GObject.idle_add(self.update_status)
            time.sleep(5)  # Update every 5 seconds

    def restart_server(self, widget):
        try:
            subprocess.run(['systemctl', '--user', 'restart', 'barrier-server'], check=True)
            os.system('notify-send "Barrier" "Server restarted" --icon=dialog-information')
        except subprocess.CalledProcessError:
            os.system('notify-send "Barrier" "Failed to restart server" --icon=dialog-error')

    def view_logs(self, widget):
        subprocess.Popen(['journalctl', '--user', '-u', 'barrier-server', '-f'])

    def quit(self, widget):
        Gtk.main_quit()

if __name__ == "__main__":
    try:
        indicator = BarrierIndicator()
        Gtk.main()
    except KeyboardInterrupt:
        pass
EOF

    chmod +x "$indicator_dir/barrier-tray.py"
    echo -e "${GREEN}✅ System tray indicator created${NC}"
}

# Function to create desktop widgets
create_desktop_widgets() {
    echo -e "${BLUE}🖥️  Creating desktop widgets...${NC}"
    
    local widgets_dir="$BARRIER_DIR/widgets"
    mkdir -p "$widgets_dir"
    
    # Create a Conky configuration for system info
    cat > "$widgets_dir/barrier-conky.conf" << EOF
-- Barrier KVM Status Widget
conky.config = {
    alignment = 'top_right',
    background = true,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    use_xft = true,
    font = 'DejaVu Sans Mono:size=10',
    gap_x = 20,
    gap_y = 60,
    maximum_width = 300,
    minimum_height = 5,
    minimum_width = 5,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_stderr = false,
    extra_newline = false,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = true,
    stippled_borders = 0,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'none',
    show_graph_scale = false,
    show_graph_range = false
}

conky.text = [[
\${color orange}Barrier KVM - $HOSTNAME\${color}
\${hr 2}
Machine Role: \${color yellow}SERVER\${color}
IP Address: \${color cyan}\${addr}\${color}
Uptime: \${uptime}
\${hr 1}
Barrier Status: \${color}\${if_running barriers}\${color green}RUNNING\${color}\${else}\${color red}STOPPED\${color}\${endif}
\${hr 1}
Memory: \$memperc% \${membar 4}
CPU: \$cpu% \${cpubar 4}
\${hr 1}
Network:
Up: \${upspeed} - Down: \${downspeed}
]]
EOF

    echo -e "${GREEN}✅ Desktop widgets created${NC}"
}

# Function to set up terminal customization
setup_terminal_customization() {
    echo -e "${BLUE}💻 Setting up terminal customization...${NC}"
    
    local profile_dir="$BARRIER_DIR/profiles"
    mkdir -p "$profile_dir"
    
    # Create custom bash profile additions
    cat > "$profile_dir/barrier-profile.sh" << EOF
# Barrier KVM Terminal Customization

# Custom PS1 with Barrier info
export BARRIER_ROLE="SERVER"
export BARRIER_HOST="$HOSTNAME"

# Enhanced prompt showing Barrier status
barrier_status() {
    if pgrep barriers >/dev/null 2>&1; then
        echo -e "\033[32m●\033[0m"  # Green dot
    else
        echo -e "\033[31m●\033[0m"  # Red dot  
    fi
}

# Custom prompt
export PS1='\[\033[01;34m\][\u@\h]\[\033[00m\] \$(barrier_status) \[\033[01;36m\]\w\[\033[00m\]\$ '

# Barrier-specific aliases
alias barrier-status='systemctl --user status barrier-server'
alias barrier-restart='systemctl --user restart barrier-server'
alias barrier-logs='journalctl --user -u barrier-server -f'
alias barrier-config='nano ~/.barrier/barrier.conf'

# Welcome message
echo -e "\033[1;34m🚀 Barrier KVM Server Environment\033[0m"
echo -e "Host: \033[1;32m$HOSTNAME\033[0m | Role: \033[1;33m$BARRIER_ROLE\033[0m"
echo -e "Quick commands: barrier-status, barrier-restart, barrier-logs"
echo ""
EOF

    echo "# Source Barrier profile" >> "$profile_dir/add-to-bashrc.txt"
    echo "source $profile_dir/barrier-profile.sh" >> "$profile_dir/add-to-bashrc.txt"
    
    echo -e "${GREEN}✅ Terminal customization ready${NC}"
    echo -e "${YELLOW}💡 Add this line to ~/.bashrc:${NC}"
    echo -e "   source $profile_dir/barrier-profile.sh"
}

# Function to create status indicator scripts
create_status_scripts() {
    echo -e "${BLUE}📊 Creating status indicator scripts...${NC}"
    
    local scripts_dir="$BARRIER_DIR/status"
    mkdir -p "$scripts_dir"
    
    # Create connection status checker
    cat > "$scripts_dir/check-connection.sh" << 'EOF'
#!/bin/bash
# Barrier Connection Status Checker

PORT=24800
HOSTNAME=$(hostname)

echo "🔍 Barrier Connection Status"
echo "============================"
echo "Server: $HOSTNAME"
echo "Port: $PORT"
echo ""

# Check if server is running
if pgrep barriers >/dev/null 2>&1; then
    echo "✅ Barrier server process: RUNNING"
else
    echo "❌ Barrier server process: NOT RUNNING"
fi

# Check if port is listening
if netstat -ln 2>/dev/null | grep ":$PORT " >/dev/null; then
    echo "✅ Port $PORT: LISTENING"
else
    echo "❌ Port $PORT: NOT LISTENING"
fi

# Check systemd service
if systemctl --user is-active barrier-server >/dev/null 2>&1; then
    echo "✅ Systemd service: ACTIVE"
else
    echo "❌ Systemd service: INACTIVE"
fi

echo ""
echo "📊 Connection Info:"
netstat -a 2>/dev/null | grep ":$PORT" || echo "No connections found"
EOF

    chmod +x "$scripts_dir/check-connection.sh"
    
    # Create visual notification script
    cat > "$scripts_dir/notify-status.sh" << 'EOF'
#!/bin/bash
# Send desktop notification about Barrier status

check_and_notify() {
    if pgrep barriers >/dev/null 2>&1; then
        notify-send "Barrier KVM" "✅ Server is running and ready for clients" \
                   --icon=network-workgroup --urgency=low
    else
        notify-send "Barrier KVM" "⚠️ Server is not running" \
                   --icon=network-offline --urgency=normal
    fi
}

# Run check
check_and_notify
EOF

    chmod +x "$scripts_dir/notify-status.sh"
    
    echo -e "${GREEN}✅ Status indicator scripts created${NC}"
}

# Main function
main() {
    print_header
    
    echo -e "${PURPLE}Creating visual indicators for better UX...${NC}"
    echo ""
    
    create_tray_indicator
    create_desktop_widgets  
    setup_terminal_customization
    create_status_scripts
    
    echo ""
    echo -e "${GREEN}🎉 Visual indicators setup complete!${NC}"
    echo ""
    echo -e "${BLUE}📁 Created files:${NC}"
    echo "  $BARRIER_DIR/indicators/barrier-tray.py - System tray indicator"
    echo "  $BARRIER_DIR/widgets/barrier-conky.conf - Desktop widget config"
    echo "  $BARRIER_DIR/profiles/barrier-profile.sh - Terminal customization"
    echo "  $BARRIER_DIR/status/ - Status checking scripts"
    echo ""
    echo -e "${BLUE}🔧 To use:${NC}"
    echo "  1. Install dependencies: sudo apt-get install python3-gi gir1.2-appindicator3-0.1 conky"
    echo "  2. Start tray indicator: python3 $BARRIER_DIR/indicators/barrier-tray.py &"
    echo "  3. Start desktop widget: conky -c $BARRIER_DIR/widgets/barrier-conky.conf &"
    echo "  4. Check connection status: $BARRIER_DIR/status/check-connection.sh"
    echo ""
    echo -e "${YELLOW}💡 Pro tip: Add the tray indicator to your startup applications!${NC}"
}

# Run main function
main "$@"