#!/bin/bash

# Barrier Configuration Manager
# Manage multiple Barrier configurations for different use cases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGS_DIR="$PROJECT_DIR/configs"
BARRIER_DIR="$HOME/.barrier"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration profiles
declare -A PROFILES=(
    ["default"]="server/barrier.conf|Default development configuration"
    ["gaming"]="configs/barrier-gaming.conf|Gaming-optimized with fast switching"
    ["development"]="configs/barrier-development.conf|Development workflow with productivity hotkeys"
    ["presentation"]="configs/barrier-presentation.conf|Presentation mode with conservative switching"
)

print_header() {
    echo -e "${BLUE}⚙️  Barrier Configuration Manager${NC}"
    echo "=================================="
    echo ""
}

show_usage() {
    echo "Usage: $0 <command> [profile]"
    echo ""
    echo "Commands:"
    echo "  list                    - List available configuration profiles"
    echo "  current                 - Show current active configuration"
    echo "  switch <profile>        - Switch to specified configuration profile"
    echo "  backup                  - Backup current configuration"
    echo "  restore <backup-file>   - Restore from backup"
    echo "  diff <profile>          - Show differences between current and profile"
    echo "  validate <profile>      - Validate configuration file"
    echo ""
    echo "Available profiles:"
    for profile in "${!PROFILES[@]}"; do
        IFS='|' read -r path description <<< "${PROFILES[$profile]}"
        echo "  $profile - $description"
    done
}

list_profiles() {
    echo -e "${BLUE}📋 Available Configuration Profiles:${NC}"
    echo ""
    
    for profile in "${!PROFILES[@]}"; do
        IFS='|' read -r path description <<< "${PROFILES[$profile]}"
        local config_file="$PROJECT_DIR/$path"
        
        if [ -f "$config_file" ]; then
            echo -e "${GREEN}✅ $profile${NC}"
            echo "   Description: $description"
            echo "   File: $config_file"
        else
            echo -e "${RED}❌ $profile${NC}"
            echo "   Description: $description"
            echo "   File: $config_file (MISSING)"
        fi
        echo ""
    done
}

show_current() {
    echo -e "${BLUE}🔍 Current Configuration Status:${NC}"
    echo ""
    
    if [ -f "$BARRIER_DIR/barrier.conf" ]; then
        echo -e "${GREEN}✅ Active configuration found${NC}"
        echo "Location: $BARRIER_DIR/barrier.conf"
        
        # Try to identify which profile is active
        local current_hash=$(md5sum "$BARRIER_DIR/barrier.conf" | cut -d' ' -f1)
        local identified=false
        
        for profile in "${!PROFILES[@]}"; do
            IFS='|' read -r path description <<< "${PROFILES[$profile]}"
            local config_file="$PROJECT_DIR/$path"
            
            if [ -f "$config_file" ]; then
                local profile_hash=$(md5sum "$config_file" | cut -d' ' -f1)
                if [ "$current_hash" = "$profile_hash" ]; then
                    echo -e "Profile: ${YELLOW}$profile${NC} ($description)"
                    identified=true
                    break
                fi
            fi
        done
        
        if [ "$identified" = false ]; then
            echo -e "Profile: ${YELLOW}custom/unknown${NC}"
        fi
        
        echo ""
        echo "Last modified: $(stat -c %y "$BARRIER_DIR/barrier.conf")"
        
        # Show service status
        if systemctl --user is-active barrier-server >/dev/null 2>&1; then
            echo -e "Service status: ${GREEN}RUNNING${NC}"
        else
            echo -e "Service status: ${RED}STOPPED${NC}"
        fi
    else
        echo -e "${RED}❌ No active configuration found${NC}"
        echo "Run './setup.sh server' to create initial configuration"
    fi
}

switch_profile() {
    local profile="$1"
    
    if [ -z "$profile" ]; then
        echo -e "${RED}❌ Error: Profile name required${NC}"
        show_usage
        return 1
    fi
    
    if [ ! "${PROFILES[$profile]+exists}" ]; then
        echo -e "${RED}❌ Error: Unknown profile '$profile'${NC}"
        echo "Available profiles: ${!PROFILES[*]}"
        return 1
    fi
    
    IFS='|' read -r path description <<< "${PROFILES[$profile]}"
    local config_file="$PROJECT_DIR/$path"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Error: Configuration file not found: $config_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Switching to profile: ${YELLOW}$profile${NC}"
    echo "Description: $description"
    echo ""
    
    # Backup current configuration
    if [ -f "$BARRIER_DIR/barrier.conf" ]; then
        local backup_file="$BARRIER_DIR/barrier.conf.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$BARRIER_DIR/barrier.conf" "$backup_file"
        echo -e "${GREEN}✅ Current configuration backed up to: $backup_file${NC}"
    fi
    
    # Copy new configuration
    cp "$config_file" "$BARRIER_DIR/barrier.conf"
    echo -e "${GREEN}✅ Configuration switched to '$profile'${NC}"
    
    # Restart service if running
    if systemctl --user is-active barrier-server >/dev/null 2>&1; then
        echo -e "${BLUE}🔄 Restarting Barrier service...${NC}"
        systemctl --user restart barrier-server
        sleep 2
        
        if systemctl --user is-active barrier-server >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Service restarted successfully${NC}"
        else
            echo -e "${RED}❌ Service failed to restart${NC}"
            echo "Check logs: journalctl --user -u barrier-server"
        fi
    else
        echo -e "${YELLOW}ℹ️  Service is not running. Start with: systemctl --user start barrier-server${NC}"
    fi
}

backup_config() {
    if [ ! -f "$BARRIER_DIR/barrier.conf" ]; then
        echo -e "${RED}❌ No configuration to backup${NC}"
        return 1
    fi
    
    local backup_file="$BARRIER_DIR/backups/barrier.conf.backup.$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BARRIER_DIR/backups"
    
    cp "$BARRIER_DIR/barrier.conf" "$backup_file"
    echo -e "${GREEN}✅ Configuration backed up to: $backup_file${NC}"
    
    # Keep only last 10 backups
    ls -t "$BARRIER_DIR/backups/"barrier.conf.backup.* 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

restore_config() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo -e "${BLUE}📁 Available backups:${NC}"
        ls -la "$BARRIER_DIR/backups/"barrier.conf.backup.* 2>/dev/null || echo "No backups found"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Backup file not found: $backup_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Restoring from backup: $backup_file${NC}"
    
    # Backup current before restoring
    backup_config
    
    cp "$backup_file" "$BARRIER_DIR/barrier.conf"
    echo -e "${GREEN}✅ Configuration restored${NC}"
    
    # Restart service if running
    if systemctl --user is-active barrier-server >/dev/null 2>&1; then
        systemctl --user restart barrier-server
    fi
}

show_diff() {
    local profile="$1"
    
    if [ -z "$profile" ]; then
        echo -e "${RED}❌ Error: Profile name required${NC}"
        return 1
    fi
    
    if [ ! "${PROFILES[$profile]+exists}" ]; then
        echo -e "${RED}❌ Error: Unknown profile '$profile'${NC}"
        return 1
    fi
    
    IFS='|' read -r path description <<< "${PROFILES[$profile]}"
    local config_file="$PROJECT_DIR/$path"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Error: Configuration file not found: $config_file${NC}"
        return 1
    fi
    
    if [ ! -f "$BARRIER_DIR/barrier.conf" ]; then
        echo -e "${RED}❌ Error: No current configuration to compare${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📊 Differences between current and '$profile':${NC}"
    echo ""
    
    if command -v colordiff >/dev/null 2>&1; then
        colordiff -u "$BARRIER_DIR/barrier.conf" "$config_file" || echo "No differences found"
    else
        diff -u "$BARRIER_DIR/barrier.conf" "$config_file" || echo "No differences found"
    fi
}

validate_config() {
    local profile="$1"
    
    if [ -z "$profile" ]; then
        profile="current"
    fi
    
    local config_file
    if [ "$profile" = "current" ]; then
        config_file="$BARRIER_DIR/barrier.conf"
    else
        if [ ! "${PROFILES[$profile]+exists}" ]; then
            echo -e "${RED}❌ Error: Unknown profile '$profile'${NC}"
            return 1
        fi
        IFS='|' read -r path description <<< "${PROFILES[$profile]}"
        config_file="$PROJECT_DIR/$path"
    fi
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Error: Configuration file not found: $config_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Validating configuration: $config_file${NC}"
    
    # Test configuration with barriers
    if barriers --config "$config_file" --check-config >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Configuration is valid${NC}"
    else
        echo -e "${RED}❌ Configuration has errors${NC}"
        barriers --config "$config_file" --check-config
    fi
}

# Main execution
main() {
    print_header
    
    local command="${1:-}"
    
    case "$command" in
        "list")
            list_profiles
            ;;
        "current")
            show_current
            ;;
        "switch")
            switch_profile "${2:-}"
            ;;
        "backup")
            backup_config
            ;;
        "restore")
            restore_config "${2:-}"
            ;;
        "diff")
            show_diff "${2:-}"
            ;;
        "validate")
            validate_config "${2:-}"
            ;;
        *)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"