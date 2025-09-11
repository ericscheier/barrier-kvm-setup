#!/bin/bash

# Barrier Cleanup and Rollback Script
# Comprehensive cleanup for failed deployments and system resets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FORCE_CLEANUP=${FORCE_CLEANUP:-false}
CLEANUP_LEVEL=${CLEANUP_LEVEL:-standard}
BACKUP_BEFORE_CLEANUP=${BACKUP_BEFORE_CLEANUP:-true}
VERBOSE=${VERBOSE:-false}

# Load environment configuration if available
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" || true
fi

print_header() {
    echo -e "${BLUE}🧹 Barrier Cleanup and Rollback${NC}"
    echo "================================="
    echo "Cleanup level: $CLEANUP_LEVEL"
    echo "Time: $(date)"
    echo ""
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_action() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Backup current configuration before cleanup
backup_current_state() {
    if [ "$BACKUP_BEFORE_CLEANUP" != "true" ]; then
        return 0
    fi
    
    log_action "Creating backup before cleanup..."
    
    local backup_dir="$HOME/.barrier/cleanup-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup active configuration
    if [ -f "$HOME/.barrier/barrier.conf" ]; then
        cp "$HOME/.barrier/barrier.conf" "$backup_dir/barrier.conf"
        log_verbose "Backed up active barrier configuration"
    fi
    
    # Backup systemd services
    if [ -f "$HOME/.config/systemd/user/barrier-server.service" ]; then
        cp "$HOME/.config/systemd/user/barrier-server.service" "$backup_dir/barrier-server.service"
        log_verbose "Backed up server service file"
    fi
    
    if [ -f "$HOME/.config/systemd/user/barrier-client.service" ]; then
        cp "$HOME/.config/systemd/user/barrier-client.service" "$backup_dir/barrier-client.service"
        log_verbose "Backed up client service file"
    fi
    
    # Backup environment file
    if [ -f "$PROJECT_DIR/.env" ]; then
        cp "$PROJECT_DIR/.env" "$backup_dir/env"
        log_verbose "Backed up environment configuration"
    fi
    
    echo "Backup created at: $backup_dir" > "$backup_dir/README.txt"
    log_success "Backup created at: $backup_dir"
}

# Stop all Barrier processes
stop_barrier_processes() {
    log_action "Stopping Barrier processes..."
    
    local stopped_count=0
    
    # Stop systemd services
    if systemctl --user is-active barrier-server >/dev/null 2>&1; then
        systemctl --user stop barrier-server || log_warning "Failed to stop barrier-server service"
        log_verbose "Stopped barrier-server service"
        ((stopped_count++))
    fi
    
    if systemctl --user is-active barrier-client >/dev/null 2>&1; then
        systemctl --user stop barrier-client || log_warning "Failed to stop barrier-client service"
        log_verbose "Stopped barrier-client service"  
        ((stopped_count++))
    fi
    
    # Kill any remaining barrier processes
    if pgrep -f barriers >/dev/null 2>&1; then
        if [ "$FORCE_CLEANUP" = "true" ]; then
            pkill -9 -f barriers || log_warning "Failed to force kill barriers processes"
            log_verbose "Force killed barriers processes"
        else
            pkill -f barriers || log_warning "Failed to terminate barriers processes"
            log_verbose "Terminated barriers processes"
        fi
        ((stopped_count++))
    fi
    
    if pgrep -f barrierc >/dev/null 2>&1; then
        if [ "$FORCE_CLEANUP" = "true" ]; then
            pkill -9 -f barrierc || log_warning "Failed to force kill barrierc processes"
            log_verbose "Force killed barrierc processes"
        else
            pkill -f barrierc || log_warning "Failed to terminate barrierc processes"
            log_verbose "Terminated barrierc processes"
        fi
        ((stopped_count++))
    fi
    
    # Wait for processes to fully stop
    sleep 2
    
    if [ "$stopped_count" -gt 0 ]; then
        log_success "Stopped $stopped_count Barrier process(es)"
    else
        log_success "No running Barrier processes found"
    fi
}

# Clean up temporary files
cleanup_temporary_files() {
    log_action "Cleaning up temporary files..."
    
    local cleaned_count=0
    
    # Remove temporary barrier files
    if find /tmp -name "barrier-*" -type f 2>/dev/null | head -1 >/dev/null; then
        find /tmp -name "barrier-*" -delete 2>/dev/null || log_warning "Failed to clean some temp files"
        ((cleaned_count++))
        log_verbose "Removed barrier temporary files from /tmp"
    fi
    
    # Remove lock files
    if [ -f "/var/lock/barriers.lock" ]; then
        rm -f /var/lock/barriers.lock || log_warning "Failed to remove barriers lock file"
        ((cleaned_count++))
        log_verbose "Removed barriers lock file"
    fi
    
    # Remove socket files
    if [ -S "$HOME/.barrier/barrier.sock" ]; then
        rm -f "$HOME/.barrier/barrier.sock" || log_warning "Failed to remove barrier socket"
        ((cleaned_count++))
        log_verbose "Removed barrier socket file"
    fi
    
    # Clean up log files if requested
    if [ "$CLEANUP_LEVEL" = "deep" ]; then
        if [ -d "$PROJECT_DIR/logs" ]; then
            find "$PROJECT_DIR/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
            ((cleaned_count++))
            log_verbose "Cleaned old log files"
        fi
    fi
    
    log_success "Cleaned up $cleaned_count temporary file location(s)"
}

# Reset systemd services
reset_systemd_services() {
    log_action "Resetting systemd services..."
    
    local reset_count=0
    
    # Disable services if they exist
    if systemctl --user is-enabled barrier-server >/dev/null 2>&1; then
        systemctl --user disable barrier-server || log_warning "Failed to disable barrier-server"
        ((reset_count++))
        log_verbose "Disabled barrier-server service"
    fi
    
    if systemctl --user is-enabled barrier-client >/dev/null 2>&1; then
        systemctl --user disable barrier-client || log_warning "Failed to disable barrier-client"
        ((reset_count++))
        log_verbose "Disabled barrier-client service"
    fi
    
    # Reload systemd daemon
    systemctl --user daemon-reload || log_warning "Failed to reload systemd daemon"
    log_verbose "Reloaded systemd daemon"
    
    # Reset failed services
    systemctl --user reset-failed barrier-server 2>/dev/null || true
    systemctl --user reset-failed barrier-client 2>/dev/null || true
    log_verbose "Reset failed service states"
    
    log_success "Reset $reset_count systemd service(s)"
}

# Remove configuration files (with confirmation)
remove_configurations() {
    if [ "$CLEANUP_LEVEL" != "deep" ] && [ "$FORCE_CLEANUP" != "true" ]; then
        log_success "Skipping configuration removal (use --deep or --force)"
        return 0
    fi
    
    log_action "Removing configuration files..."
    
    local removed_count=0
    
    # Remove systemd service files
    if [ -f "$HOME/.config/systemd/user/barrier-server.service" ]; then
        rm -f "$HOME/.config/systemd/user/barrier-server.service" || log_warning "Failed to remove server service file"
        ((removed_count++))
        log_verbose "Removed barrier-server service file"
    fi
    
    if [ -f "$HOME/.config/systemd/user/barrier-client.service" ]; then
        rm -f "$HOME/.config/systemd/user/barrier-client.service" || log_warning "Failed to remove client service file"
        ((removed_count++))
        log_verbose "Removed barrier-client service file"
    fi
    
    # Remove barrier configuration directory
    if [ "$CLEANUP_LEVEL" = "deep" ] && [ -d "$HOME/.barrier" ]; then
        if [ "$FORCE_CLEANUP" = "true" ]; then
            rm -rf "$HOME/.barrier" || log_warning "Failed to remove barrier directory"
            ((removed_count++))
            log_verbose "Removed entire barrier configuration directory"
        else
            # Only remove specific files, keep backups
            rm -f "$HOME/.barrier/barrier.conf" 2>/dev/null || true
            rm -f "$HOME/.barrier/barriers.log" 2>/dev/null || true
            ((removed_count++))
            log_verbose "Removed barrier configuration files (kept backups)"
        fi
    fi
    
    # Remove desktop autostart entries
    if [ -f "$HOME/.config/autostart/barrier-client.desktop" ]; then
        rm -f "$HOME/.config/autostart/barrier-client.desktop" || log_warning "Failed to remove autostart entry"
        ((removed_count++))
        log_verbose "Removed desktop autostart entry"
    fi
    
    log_success "Removed $removed_count configuration file(s)"
}

# Clean network configuration
cleanup_network_config() {
    log_action "Cleaning up network configuration..."
    
    # This is a placeholder for network-specific cleanup
    # In a real deployment, this might remove firewall rules, etc.
    
    # Note: We don't automatically remove firewall rules as they might be used by other services
    log_success "Network configuration cleanup completed"
}

# Restore from backup if available
restore_from_backup() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_action "Restoring from backup: $backup_path"
    
    local restored_count=0
    
    # Restore barrier configuration
    if [ -f "$backup_path/barrier.conf" ]; then
        mkdir -p "$HOME/.barrier"
        cp "$backup_path/barrier.conf" "$HOME/.barrier/barrier.conf"
        ((restored_count++))
        log_verbose "Restored barrier configuration"
    fi
    
    # Restore systemd services
    if [ -f "$backup_path/barrier-server.service" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp "$backup_path/barrier-server.service" "$HOME/.config/systemd/user/"
        ((restored_count++))
        log_verbose "Restored server service file"
    fi
    
    if [ -f "$backup_path/barrier-client.service" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp "$backup_path/barrier-client.service" "$HOME/.config/systemd/user/"
        ((restored_count++))
        log_verbose "Restored client service file"
    fi
    
    # Restore environment configuration
    if [ -f "$backup_path/env" ]; then
        cp "$backup_path/env" "$PROJECT_DIR/.env"
        ((restored_count++))
        log_verbose "Restored environment configuration"
    fi
    
    # Reload systemd after restoration
    systemctl --user daemon-reload || log_warning "Failed to reload systemd after restoration"
    
    log_success "Restored $restored_count file(s) from backup"
}

# Generate cleanup report
generate_cleanup_report() {
    echo ""
    echo -e "${BLUE}📊 Cleanup Summary${NC}"
    echo "==================="
    echo "Cleanup level: $CLEANUP_LEVEL"
    echo "Force cleanup: $FORCE_CLEANUP"
    echo "Backup created: $BACKUP_BEFORE_CLEANUP"
    echo ""
    
    # Check final state
    if ! pgrep -f "barrier[cs]" >/dev/null 2>&1; then
        log_success "No barrier processes running"
    else
        log_warning "Some barrier processes may still be running"
    fi
    
    if [ "$CLEANUP_LEVEL" = "deep" ]; then
        log_success "Deep cleanup completed - system reset to initial state"
    else
        log_success "Standard cleanup completed - configurations preserved"
    fi
    
    echo ""
    echo "Next steps:"
    echo "  - To reinstall: ./setup.sh [server|client]"
    echo "  - To restore from backup: $0 --restore <backup-path>"
    echo "  - To verify installation: ./scripts/verify-installation.sh"
}

# Command line argument processing
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --standard      Standard cleanup (default) - stop services, clean temps"
    echo "  --deep          Deep cleanup - remove configurations too"
    echo "  --force         Force cleanup without prompts"
    echo "  --no-backup     Skip backup creation"
    echo "  --restore PATH  Restore from backup directory"
    echo "  --verbose       Enable verbose output"
    echo ""
    echo "Environment variables:"
    echo "  CLEANUP_LEVEL={standard|deep}"
    echo "  FORCE_CLEANUP={true|false}"
    echo "  BACKUP_BEFORE_CLEANUP={true|false}"
    echo "  VERBOSE={true|false}"
}

# Main execution
main() {
    print_header
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --standard)
                CLEANUP_LEVEL="standard"
                shift
                ;;
            --deep)
                CLEANUP_LEVEL="deep"
                shift
                ;;
            --force)
                FORCE_CLEANUP="true"
                shift
                ;;
            --no-backup)
                BACKUP_BEFORE_CLEANUP="false"
                shift
                ;;
            --restore)
                if [ -n "${2:-}" ]; then
                    restore_from_backup "$2"
                    return $?
                else
                    echo "Error: --restore requires backup directory path"
                    return 1
                fi
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                return 1
                ;;
        esac
    done
    
    # Confirmation for deep cleanup
    if [ "$CLEANUP_LEVEL" = "deep" ] && [ "$FORCE_CLEANUP" != "true" ]; then
        echo -e "${YELLOW}⚠️  Deep cleanup will remove all barrier configurations.${NC}"
        echo "This action cannot be undone (unless you have backups)."
        echo ""
        read -p "Continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cleanup cancelled."
            return 0
        fi
    fi
    
    # Execute cleanup steps
    backup_current_state
    stop_barrier_processes
    cleanup_temporary_files
    reset_systemd_services
    remove_configurations
    cleanup_network_config
    
    generate_cleanup_report
}

# Run main function with all arguments
main "$@"