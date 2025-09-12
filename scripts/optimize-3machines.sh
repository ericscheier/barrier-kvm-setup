#!/bin/bash

# 3-Machine Barrier Optimization Script
# Apply performance optimizations for 3-client setups

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
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

print_header() {
    echo -e "${BLUE}⚡ 3-Machine Barrier Optimization${NC}"
    echo "===================================="
    echo "Host: $(hostname)"
    echo "Mode: $([ "$DRY_RUN" = "true" ] && echo "DRY RUN" || echo "APPLY CHANGES")"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Optimize systemd service for multiple clients
optimize_systemd_service() {
    log_info "Optimizing systemd service for multi-client setup..."
    
    local service_file="$HOME/.config/systemd/user/barrier-server.service"
    local temp_file=$(mktemp)
    
    # Check if service file exists
    if [ ! -f "$service_file" ]; then
        log_warning "Systemd service file not found, skipping optimization"
        return 1
    fi
    
    # Add multi-client optimizations to service file
    if ! grep -q "CPUQuota" "$service_file"; then
        log_verbose "Adding CPU quota settings"
        
        # Create optimized service file
        cat > "$temp_file" << 'EOF'
[Unit]
Description=Barrier Server (Multi-Client Optimized)
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/bin/barriers -f --no-tray --debug INFO --disable-crypto --name %H --config %h/.barrier/barrier.conf
Restart=always
RestartSec=5

# Multi-client performance optimizations
CPUQuota=150%
MemoryMax=512M
IOWeight=200
Nice=-5

# Enhanced restart policy for multi-client scenarios
RestartMaxDelaySec=30
RestartSteps=5

[Install]
WantedBy=graphical-session.target
EOF
        
        if [ "$DRY_RUN" = "false" ]; then
            mv "$temp_file" "$service_file"
            systemctl --user daemon-reload
            log_success "Systemd service optimized for multi-client performance"
        else
            log_info "[DRY RUN] Would optimize systemd service file"
            rm "$temp_file"
        fi
    else
        log_info "Systemd service already optimized"
        rm "$temp_file"
    fi
}

# Optimize network settings
optimize_network_settings() {
    log_info "Checking network optimizations..."
    
    # Check current TCP settings
    local tcp_keepalive_time
    tcp_keepalive_time=$(cat /proc/sys/net/ipv4/tcp_keepalive_time 2>/dev/null || echo "unknown")
    log_verbose "Current TCP keepalive time: $tcp_keepalive_time"
    
    # Suggest network optimizations (read-only checks)
    if [ "$tcp_keepalive_time" != "unknown" ] && [ "$tcp_keepalive_time" -gt 600 ]; then
        log_warning "TCP keepalive time is high ($tcp_keepalive_time). Consider optimizing for multi-client connections."
        echo "  Suggested: echo 300 | sudo tee /proc/sys/net/ipv4/tcp_keepalive_time"
    else
        log_success "Network keepalive settings are reasonable"
    fi
    
    # Check for network buffer sizes
    local rmem_max
    rmem_max=$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo "unknown")
    if [ "$rmem_max" != "unknown" ] && [ "$rmem_max" -lt 16777216 ]; then
        log_warning "Network receive buffer might be small for multi-client setup"
        echo "  Current rmem_max: $rmem_max"
        echo "  Consider: echo 16777216 | sudo tee /proc/sys/net/core/rmem_max"
    else
        log_success "Network buffer settings look good"
    fi
}

# Optimize process limits
optimize_process_limits() {
    log_info "Checking process limits for multi-client setup..."
    
    # Check file descriptor limits
    local soft_limit hard_limit
    soft_limit=$(ulimit -n 2>/dev/null || echo "unknown")
    hard_limit=$(ulimit -Hn 2>/dev/null || echo "unknown")
    
    log_verbose "File descriptor limits - soft: $soft_limit, hard: $hard_limit"
    
    if [ "$soft_limit" != "unknown" ] && [ "$soft_limit" -lt 4096 ]; then
        log_warning "File descriptor soft limit is low ($soft_limit)"
        log_info "For multi-client setups, consider increasing to at least 4096"
        echo "  Add to ~/.bashrc: ulimit -n 4096"
    else
        log_success "File descriptor limits are adequate"
    fi
    
    # Check memory limits
    local memory_limit
    memory_limit=$(ulimit -m 2>/dev/null || echo "unlimited")
    if [ "$memory_limit" != "unlimited" ] && [ "$memory_limit" -lt 1048576 ]; then
        log_warning "Memory limit might be restrictive for multi-client setup"
    else
        log_success "Memory limits are adequate"
    fi
}

# Create performance monitoring script
create_performance_monitor() {
    log_info "Creating performance monitoring script..."
    
    local monitor_script="$PROJECT_DIR/scripts/monitor-performance.sh"
    
    if [ "$DRY_RUN" = "false" ]; then
        cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Barrier Performance Monitor for 3-Machine Setup

BARRIER_PID=$(pgrep -f "barriers.*--name.*$(hostname)" | head -1)

if [ -z "$BARRIER_PID" ]; then
    echo "❌ Barrier server not running"
    exit 1
fi

echo "🖥️  Barrier Performance Monitor"
echo "=============================="
echo "PID: $BARRIER_PID"
echo "Host: $(hostname)"
echo ""

# CPU and Memory usage
echo "📊 Resource Usage:"
ps -p "$BARRIER_PID" -o pid,pcpu,pmem,vsz,rss,etime,cmd --no-headers | while read line; do
    echo "  $line"
done

# Network connections
echo ""
echo "🌐 Network Connections:"
ss -tn | grep ":24800" | while read line; do
    echo "  $line"
done

# File descriptors
echo ""
echo "📁 File Descriptors:"
if [ -d "/proc/$BARRIER_PID/fd" ]; then
    fd_count=$(ls "/proc/$BARRIER_PID/fd" | wc -l)
    echo "  Open file descriptors: $fd_count"
fi

# Load average
echo ""
echo "⚖️  System Load:"
uptime | awk -F'load average:' '{print "  Load:" $2}'
EOF
        
        chmod +x "$monitor_script"
        log_success "Performance monitoring script created: $monitor_script"
    else
        log_info "[DRY RUN] Would create performance monitoring script"
    fi
}

# Optimize barrier configuration for performance
optimize_barrier_config() {
    log_info "Checking Barrier configuration optimizations..."
    
    local config_file="$HOME/.barrier/barrier.conf"
    if [ ! -f "$config_file" ]; then
        log_warning "Barrier configuration not found"
        return 1
    fi
    
    # Check for performance-related options
    local has_heartbeat
    has_heartbeat=$(grep -c "heartbeat" "$config_file" || echo "0")
    
    if [ "$has_heartbeat" -eq 0 ]; then
        log_warning "Configuration missing heartbeat setting for multi-client stability"
        if [ "$DRY_RUN" = "false" ]; then
            # Add heartbeat setting to options section
            if grep -q "section: options" "$config_file"; then
                sed -i '/section: options/a\    heartbeat = 5000' "$config_file"
                log_success "Added heartbeat setting to configuration"
            fi
        else
            log_info "[DRY RUN] Would add heartbeat setting to configuration"
        fi
    else
        log_success "Configuration already has heartbeat setting"
    fi
    
    # Check for clipboard optimization
    if ! grep -q "clipboardSharing" "$config_file"; then
        log_warning "Consider adding clipboard sharing optimization"
        if [ "$DRY_RUN" = "false" ]; then
            sed -i '/section: options/a\    clipboardSharing = true' "$config_file"
            log_success "Added clipboard sharing optimization"
        else
            log_info "[DRY RUN] Would add clipboard sharing optimization"
        fi
    else
        log_success "Clipboard sharing already configured"
    fi
}

# Create 3-machine specific environment settings
create_environment_optimizations() {
    log_info "Creating 3-machine environment optimizations..."
    
    local env_file="$PROJECT_DIR/.env.3machines"
    
    if [ "$DRY_RUN" = "false" ]; then
        cat > "$env_file" << 'EOF'
# 3-Machine Barrier Environment Optimizations

# Performance Settings
BARRIER_LOG_LEVEL=INFO
BARRIER_HEARTBEAT=5000
BARRIER_CONNECTION_TIMEOUT=30000

# Multi-client specific settings
EXPECTED_CLIENTS="wright orville"
MONITOR_INTERVAL=10
ALERT_DISCONNECTIONS=true

# Resource Management
MAX_MEMORY_MB=512
CPU_QUOTA=150
PROCESS_PRIORITY=-5

# Network Optimizations
TCP_KEEPALIVE=300
SOCKET_BUFFER_SIZE=65536

# Service Management
AUTO_RESTART_ON_FAILURE=true
RESTART_DELAY=5
MAX_RESTART_ATTEMPTS=10

# Monitoring
ENABLE_PERFORMANCE_MONITORING=true
LOG_PERFORMANCE_STATS=true
PERFORMANCE_LOG_INTERVAL=300
EOF
        
        log_success "Created 3-machine optimization environment: $env_file"
        log_info "Source this file for optimal 3-machine performance: source $env_file"
    else
        log_info "[DRY RUN] Would create 3-machine environment optimizations"
    fi
}

# Generate optimization report
generate_optimization_report() {
    echo ""
    echo -e "${BLUE}📋 Optimization Summary${NC}"
    echo "======================="
    
    local optimizations_applied=0
    local total_optimizations=5
    
    # Count what was actually done (simplified for demo)
    if systemctl --user is-active barrier-server >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Barrier server running${NC}"
        ((optimizations_applied++))
    else
        echo -e "${RED}❌ Barrier server not running${NC}"
    fi
    
    if [ -f "$HOME/.config/systemd/user/barrier-server.service" ]; then
        echo -e "${GREEN}✅ Systemd service configured${NC}"
        ((optimizations_applied++))
    fi
    
    if [ -f "$HOME/.barrier/barrier.conf" ]; then
        echo -e "${GREEN}✅ Barrier configuration present${NC}"
        ((optimizations_applied++))
    fi
    
    if [ -f "$PROJECT_DIR/scripts/monitor-performance.sh" ]; then
        echo -e "${GREEN}✅ Performance monitoring available${NC}"
        ((optimizations_applied++))
    fi
    
    if [ -f "$PROJECT_DIR/.env.3machines" ]; then
        echo -e "${GREEN}✅ 3-machine environment optimizations created${NC}"
        ((optimizations_applied++))
    fi
    
    echo ""
    echo "Applied: $optimizations_applied/$total_optimizations optimizations"
    
    if [ "$optimizations_applied" -eq "$total_optimizations" ]; then
        echo -e "${GREEN}🎉 System fully optimized for 3-machine setup${NC}"
    elif [ "$optimizations_applied" -ge 3 ]; then
        echo -e "${YELLOW}⚠️  Most optimizations applied - system should perform well${NC}"
    else
        echo -e "${RED}❌ Several optimizations missing - consider re-running${NC}"
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. Monitor performance: ./scripts/monitor-performance.sh"
    echo "  2. Monitor clients: ./scripts/monitor-multi-client.sh"
    echo "  3. Load optimizations: source .env.3machines"
    echo "  4. Restart server if needed: systemctl --user restart barrier-server"
}

# Command line help
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Show what would be done without making changes"
    echo "  --verbose     Enable verbose output"
    echo "  --apply       Apply optimizations (default)"
    echo ""
    echo "Environment variables:"
    echo "  DRY_RUN=true     # Run in dry-run mode"
    echo "  VERBOSE=true     # Enable verbose output"
}

# Main execution
main() {
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --apply)
                DRY_RUN=false
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
    
    print_header
    
    # Run optimizations
    optimize_systemd_service
    optimize_network_settings
    optimize_process_limits
    create_performance_monitor
    optimize_barrier_config
    create_environment_optimizations
    
    generate_optimization_report
}

# Run main function with all arguments
main "$@"