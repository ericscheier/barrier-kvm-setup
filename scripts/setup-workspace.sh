#!/bin/bash

# Workspace Setup Script for Barrier KVM
# Helps configure optimal multi-monitor workflows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME=$(hostname)

echo "🖥️  Setting up multi-monitor workspace for $HOSTNAME"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to detect desktop environment
detect_de() {
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [ "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"
    else
        echo "unknown"
    fi
}

# Function to set wallpaper based on DE
set_wallpaper() {
    local wallpaper_path="$1"
    local de=$(detect_de)
    
    case "$de" in
        "GNOME"|"ubuntu:GNOME")
            gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path"
            ;;
        "KDE"|"plasma")
            # KDE/Plasma wallpaper setting is more complex, skipping for now
            print_warning "KDE wallpaper setting not implemented yet"
            ;;
        "XFCE")
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$wallpaper_path"
            ;;
        *)
            print_warning "Unknown desktop environment: $de. Skipping wallpaper setup."
            ;;
    esac
}

# Function to create workspace directories
setup_directories() {
    print_step "Setting up workspace directories"
    
    mkdir -p ~/workspace/{server,client,shared}
    mkdir -p ~/workspace/shared/{documents,downloads,screenshots}
    
    print_success "Workspace directories created"
}

# Function to create identification wallpapers
create_identification_wallpapers() {
    print_step "Creating identification wallpapers"
    
    local wallpaper_dir="$HOME/.barrier/wallpapers"
    mkdir -p "$wallpaper_dir"
    
    # Create simple colored wallpapers with hostname
    if command -v convert >/dev/null 2>&1; then
        # Server wallpaper (blue)
        convert -size 1920x1080 xc:'#1e3a8a' \
                -pointsize 72 -fill white -gravity center \
                -annotate +0+0 "SERVER\n$HOSTNAME" \
                "$wallpaper_dir/server-bg.png"
        
        # Client wallpaper (green)  
        convert -size 1920x1080 xc:'#166534' \
                -pointsize 72 -fill white -gravity center \
                -annotate +0+0 "CLIENT\n$HOSTNAME" \
                "$wallpaper_dir/client-bg.png"
                
        print_success "Identification wallpapers created"
    else
        print_warning "ImageMagick not found. Skipping wallpaper creation."
        echo "Install with: sudo apt-get install imagemagick"
    fi
}

# Function to configure display settings
configure_displays() {
    print_step "Configuring display settings"
    
    echo "Current display configuration:"
    if command -v xrandr >/dev/null 2>&1; then
        xrandr | grep " connected"
    else
        print_warning "xrandr not available"
    fi
    
    print_success "Display configuration checked"
}

# Function to create application shortcuts
create_shortcuts() {
    print_step "Creating application shortcuts"
    
    local shortcuts_dir="$HOME/.barrier/shortcuts"
    mkdir -p "$shortcuts_dir"
    
    # Create a script to launch common development applications
    cat > "$shortcuts_dir/dev-setup.sh" << 'EOF'
#!/bin/bash
# Development environment setup

# Terminal with barrier project
gnome-terminal --working-directory="$HOME/Documents/apps/barrier" &

# Code editor (if available)
if command -v code >/dev/null 2>&1; then
    code "$HOME/Documents/apps/barrier" &
elif command -v gedit >/dev/null 2>&1; then
    gedit &
fi

# File manager
if command -v nautilus >/dev/null 2>&1; then
    nautilus "$HOME/workspace" &
elif command -v thunar >/dev/null 2>&1; then
    thunar "$HOME/workspace" &
fi
EOF

    chmod +x "$shortcuts_dir/dev-setup.sh"
    
    print_success "Application shortcuts created"
}

# Function to configure system settings
configure_system() {
    print_step "Configuring system settings"
    
    # Set mouse sensitivity (if possible)
    if command -v xinput >/dev/null 2>&1; then
        # List input devices
        echo "Available input devices:"
        xinput list | grep -i mouse
    fi
    
    # Configure screen saver sync
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.screensaver idle-activation-enabled true
        print_success "Screen saver settings configured"
    fi
}

# Function to create monitor layout helper
create_layout_helper() {
    print_step "Creating monitor layout helper"
    
    cat > "$HOME/.barrier/monitor-layout.sh" << 'EOF'
#!/bin/bash
# Monitor Layout Helper

echo "🖥️  Current Monitor Layout:"
echo "=========================="

if command -v xrandr >/dev/null 2>&1; then
    xrandr | grep " connected" | while read output; do
        echo "- $output"
    done
else
    echo "xrandr not available"
fi

echo ""
echo "💡 Barrier Tips:"
echo "- Move mouse to screen edges to switch machines"
echo "- Use Ctrl+Alt+Arrow keys for hotkey switching"
echo "- Use Ctrl+Alt+Home/End for direct machine switching"
EOF

    chmod +x "$HOME/.barrier/monitor-layout.sh"
    
    print_success "Monitor layout helper created"
}

# Main execution
main() {
    print_step "Starting Barrier workspace setup"
    
    setup_directories
    create_identification_wallpapers
    configure_displays
    create_shortcuts
    configure_system
    create_layout_helper
    
    echo ""
    print_success "🎉 Workspace setup complete!"
    echo ""
    echo "📁 Created directories:"
    echo "   ~/workspace/{server,client,shared}"
    echo "   ~/.barrier/{wallpapers,shortcuts}"
    echo ""
    echo "🔧 Created utilities:"
    echo "   ~/.barrier/shortcuts/dev-setup.sh - Launch development environment"
    echo "   ~/.barrier/monitor-layout.sh - Check monitor configuration"
    echo ""
    echo "🎨 Next steps:"
    echo "   1. Set wallpapers: ~/.barrier/wallpapers/server-bg.png or client-bg.png"
    echo "   2. Run monitor layout helper: ~/.barrier/monitor-layout.sh"
    echo "   3. Test hotkeys: Ctrl+Alt+Arrow keys"
}

# Run main function
main "$@"