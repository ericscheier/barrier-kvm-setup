#!/bin/bash

# Barrier System Backup Script
# Creates comprehensive backups of Barrier setup for easy restoration

set -euo pipefail

HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/.barrier/system-backups"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}💾 Barrier System Backup${NC}"
    echo "========================"
    echo "Host: $HOSTNAME"
    echo "Time: $(date)"
    echo ""
}

create_backup() {
    local backup_name="${1:-auto-$TIMESTAMP}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo -e "${BLUE}Creating backup: $backup_name${NC}"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup configurations
    echo "📋 Backing up configurations..."
    mkdir -p "$backup_path/configs"
    
    # Active configuration
    if [ -f "$HOME/.barrier/barrier.conf" ]; then
        cp "$HOME/.barrier/barrier.conf" "$backup_path/configs/active-barrier.conf"
        echo "  ✅ Active barrier.conf"
    fi
    
    # All project configurations
    if [ -d "$PROJECT_DIR/configs" ]; then
        cp -r "$PROJECT_DIR/configs/"* "$backup_path/configs/" 2>/dev/null || true
        echo "  ✅ Project configurations"
    fi
    
    # Server configuration
    if [ -f "$PROJECT_DIR/server/barrier.conf" ]; then
        cp "$PROJECT_DIR/server/barrier.conf" "$backup_path/configs/server-barrier.conf"
        echo "  ✅ Server configuration"
    fi
    
    # Backup systemd service
    echo "⚙️  Backing up systemd service..."
    mkdir -p "$backup_path/systemd"
    
    if [ -f "$HOME/.config/systemd/user/barrier-server.service" ]; then
        cp "$HOME/.config/systemd/user/barrier-server.service" "$backup_path/systemd/"
        echo "  ✅ systemd service file"
    fi
    
    # Backup scripts
    echo "📜 Backing up scripts..."
    mkdir -p "$backup_path/scripts"
    
    if [ -d "$PROJECT_DIR/scripts" ]; then
        cp -r "$PROJECT_DIR/scripts/"* "$backup_path/scripts/" 2>/dev/null || true
        echo "  ✅ Custom scripts"
    fi
    
    # Backup server files
    if [ -d "$PROJECT_DIR/server" ]; then
        cp -r "$PROJECT_DIR/server" "$backup_path/"
        echo "  ✅ Server files"
    fi
    
    # Backup documentation
    echo "📚 Backing up documentation..."
    if [ -d "$PROJECT_DIR/docs" ]; then
        cp -r "$PROJECT_DIR/docs" "$backup_path/"
        echo "  ✅ Documentation"
    fi
    
    # Backup personal customizations
    echo "🎨 Backing up customizations..."
    mkdir -p "$backup_path/personal"
    
    if [ -d "$HOME/.barrier/wallpapers" ]; then
        cp -r "$HOME/.barrier/wallpapers" "$backup_path/personal/"
        echo "  ✅ Custom wallpapers"
    fi
    
    if [ -d "$HOME/.barrier/profiles" ]; then
        cp -r "$HOME/.barrier/profiles" "$backup_path/personal/"
        echo "  ✅ Terminal profiles"
    fi
    
    # System information
    echo "🖥️  Collecting system information..."
    mkdir -p "$backup_path/system-info"
    
    # Hardware info
    lshw -short > "$backup_path/system-info/hardware.txt" 2>/dev/null || true
    lscpu > "$backup_path/system-info/cpu.txt" 2>/dev/null || true
    lsusb > "$backup_path/system-info/usb.txt" 2>/dev/null || true
    
    # Network info
    ip addr > "$backup_path/system-info/network.txt" 2>/dev/null || true
    ss -tuln > "$backup_path/system-info/ports.txt" 2>/dev/null || true
    
    # Display info
    if command -v xrandr >/dev/null 2>&1; then
        xrandr > "$backup_path/system-info/displays.txt" 2>/dev/null || true
    fi
    
    # Package versions
    dpkg -l | grep barrier > "$backup_path/system-info/barrier-packages.txt" 2>/dev/null || true
    
    # Environment info
    env | grep -E "(DISPLAY|XDG|DESKTOP)" > "$backup_path/system-info/environment.txt" 2>/dev/null || true
    
    # Service status
    systemctl --user status barrier-server --no-pager > "$backup_path/system-info/service-status.txt" 2>/dev/null || true
    
    # Recent logs (last 100 lines)
    journalctl --user -u barrier-server -n 100 --no-pager > "$backup_path/system-info/recent-logs.txt" 2>/dev/null || true
    
    # Create backup metadata
    cat > "$backup_path/backup-info.txt" << EOF
Barrier System Backup
====================
Created: $(date)
Hostname: $HOSTNAME
Backup Name: $backup_name
Backup Path: $backup_path

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Barrier Version: $(barriers --version 2>&1 | head -1 || echo "Unknown")

Service Status:
$(systemctl --user is-active barrier-server 2>/dev/null || echo "inactive")

Active Configuration Hash:
$(md5sum "$HOME/.barrier/barrier.conf" 2>/dev/null | cut -d' ' -f1 || echo "No active config")

Backup Contents:
$(find "$backup_path" -type f | wc -l) files
$(du -sh "$backup_path" | cut -f1) total size
EOF
    
    # Create restoration script
    cat > "$backup_path/restore.sh" << 'EOF'
#!/bin/bash
# Barrier Backup Restoration Script
# Auto-generated during backup creation

set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🔄 Restoring Barrier configuration from: $BACKUP_DIR"

# Stop service if running
if systemctl --user is-active barrier-server >/dev/null 2>&1; then
    echo "⏹️  Stopping Barrier service..."
    systemctl --user stop barrier-server
fi

# Restore active configuration
if [ -f "$BACKUP_DIR/configs/active-barrier.conf" ]; then
    mkdir -p "$HOME/.barrier"
    cp "$BACKUP_DIR/configs/active-barrier.conf" "$HOME/.barrier/barrier.conf"
    echo "✅ Active configuration restored"
fi

# Restore systemd service
if [ -f "$BACKUP_DIR/systemd/barrier-server.service" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp "$BACKUP_DIR/systemd/barrier-server.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    echo "✅ systemd service restored"
fi

# Restore personal customizations
if [ -d "$BACKUP_DIR/personal" ]; then
    cp -r "$BACKUP_DIR/personal/"* "$HOME/.barrier/" 2>/dev/null || true
    echo "✅ Personal customizations restored"
fi

echo "🎉 Restoration complete!"
echo ""
echo "To start the service:"
echo "  systemctl --user start barrier-server"
echo ""
echo "To check status:"
echo "  systemctl --user status barrier-server"
EOF
    
    chmod +x "$backup_path/restore.sh"
    
    # Create archive
    echo "📦 Creating archive..."
    cd "$BACKUP_DIR"
    tar -czf "$backup_name.tar.gz" "$backup_name"
    
    # Cleanup directory (keep archive)
    rm -rf "$backup_name"
    
    echo ""
    echo -e "${GREEN}✅ Backup completed successfully!${NC}"
    echo -e "Archive: ${YELLOW}$BACKUP_DIR/$backup_name.tar.gz${NC}"
    echo -e "Size: $(du -sh "$BACKUP_DIR/$backup_name.tar.gz" | cut -f1)"
    echo ""
    echo "To restore:"
    echo "  tar -xzf $backup_name.tar.gz"
    echo "  cd $backup_name"
    echo "  ./restore.sh"
}

list_backups() {
    echo -e "${BLUE}📁 Available Backups:${NC}"
    echo ""
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR")" ]; then
        cd "$BACKUP_DIR"
        for backup in *.tar.gz; do
            if [ -f "$backup" ]; then
                local size=$(du -sh "$backup" | cut -f1)
                local date=$(stat -c %y "$backup" | cut -d. -f1)
                echo -e "${GREEN}📦 $backup${NC}"
                echo "   Size: $size"
                echo "   Created: $date"
                echo ""
            fi
        done
    else
        echo "No backups found."
    fi
}

restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}❌ Please specify backup file${NC}"
        list_backups
        return 1
    fi
    
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        echo -e "${RED}❌ Backup file not found: $BACKUP_DIR/$backup_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Restoring from backup: $backup_file${NC}"
    
    # Extract to temporary location
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    tar -xzf "$BACKUP_DIR/$backup_file"
    
    # Find and run restore script
    local restore_script=$(find . -name "restore.sh" | head -1)
    if [ -f "$restore_script" ]; then
        chmod +x "$restore_script"
        "$restore_script"
    else
        echo -e "${RED}❌ No restore script found in backup${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✅ Restore completed${NC}"
}

cleanup_old_backups() {
    local keep_count="${1:-5}"
    
    echo -e "${BLUE}🧹 Cleaning up old backups (keeping $keep_count most recent)${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        cd "$BACKUP_DIR"
        ls -t *.tar.gz 2>/dev/null | tail -n +$((keep_count + 1)) | xargs rm -f
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    fi
}

show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create [name]     - Create a new backup (optional custom name)"
    echo "  list              - List available backups"
    echo "  restore <file>    - Restore from backup file"
    echo "  cleanup [count]   - Remove old backups (default: keep 5)"
    echo ""
    echo "Examples:"
    echo "  $0 create                    # Create auto-named backup"
    echo "  $0 create before-upgrade     # Create custom-named backup"
    echo "  $0 restore auto-20240909.tar.gz"
    echo "  $0 cleanup 3                 # Keep only 3 most recent"
}

# Main execution
main() {
    print_header
    
    local command="${1:-}"
    
    case "$command" in
        "create")
            create_backup "${2:-}"
            ;;
        "list")
            list_backups
            ;;
        "restore")
            restore_backup "${2:-}"
            ;;
        "cleanup")
            cleanup_old_backups "${2:-5}"
            ;;
        *)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"