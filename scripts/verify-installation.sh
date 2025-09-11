#!/bin/bash

# Barrier Installation Verification Script
# Comprehensive health checks for polyglot-workbench integration

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
VERBOSE=${VERBOSE:-false}
EXIT_ON_FAILURE=${EXIT_ON_FAILURE:-false}
VERIFY_NETWORK=${VERIFY_NETWORK:-true}
VERIFY_DISPLAY=${VERIFY_DISPLAY:-true}

# Load environment configuration if available
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
elif [ -f "$PROJECT_DIR/.env.example" ]; then
    # Use example as fallback
    source "$PROJECT_DIR/.env.example" || true
fi

# Set defaults
BARRIER_SERVER_IP=${BARRIER_SERVER_IP:-"192.168.1.206"}
BARRIER_PORT=${BARRIER_PORT:-24800}
DISPLAY=${DISPLAY:-":0"}

print_header() {
    echo -e "${BLUE}🔍 Barrier Installation Verification${NC}"
    echo "====================================="
    echo "Project: $(basename "$PROJECT_DIR")"
    echo "Time: $(date)"
    echo ""
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

check_passed() {
    echo -e "${GREEN}✅ $1${NC}"
    return 0
}

check_failed() {
    echo -e "${RED}❌ $1${NC}"
    if [ "$EXIT_ON_FAILURE" = "true" ]; then
        exit 1
    fi
    return 1
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    return 1
}

# Core Installation Checks
verify_barrier_installation() {
    echo -e "${BLUE}📦 Checking Barrier Installation...${NC}"
    
    local checks_passed=0
    local total_checks=4
    
    # Check barrierc (client)
    if command -v barrierc >/dev/null 2>&1; then
        local client_version
        client_version=$(barrierc --version 2>&1 | head -1 || echo "unknown")
        check_passed "Barrier client installed: $client_version"
        ((checks_passed++))
    else
        check_failed "Barrier client (barrierc) not found"
    fi
    
    # Check barriers (server)
    if command -v barriers >/dev/null 2>&1; then
        local server_version
        server_version=$(barriers --version 2>&1 | head -1 || echo "unknown")
        check_passed "Barrier server installed: $server_version"
        ((checks_passed++))
    else
        check_failed "Barrier server (barriers) not found"
    fi
    
    # Check version compatibility
    if command -v barrierc >/dev/null 2>&1 && command -v barriers >/dev/null 2>&1; then
        local client_ver server_ver
        client_ver=$(barrierc --version 2>&1 | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
        server_ver=$(barriers --version 2>&1 | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
        
        if [ "$client_ver" = "$server_ver" ]; then
            check_passed "Version compatibility verified: $client_ver"
            ((checks_passed++))
        else
            check_warning "Version mismatch: client=$client_ver, server=$server_ver"
        fi
    fi
    
    # Check configuration files
    if [ -f "$HOME/.barrier/barrier.conf" ] || [ -f "$PROJECT_DIR/server/barrier.conf" ]; then
        check_passed "Barrier configuration files found"
        ((checks_passed++))
    else
        check_warning "No barrier configuration files found"
    fi
    
    echo "Installation check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# Network Connectivity Checks
verify_network_connectivity() {
    if [ "$VERIFY_NETWORK" != "true" ]; then
        return 0
    fi
    
    echo -e "${BLUE}🌐 Checking Network Connectivity...${NC}"
    
    local checks_passed=0
    local total_checks=4
    
    # Check if barrier server IP is reachable
    if ping -c 1 -W 2 "$BARRIER_SERVER_IP" >/dev/null 2>&1; then
        check_passed "Server IP reachable: $BARRIER_SERVER_IP"
        ((checks_passed++))
    else
        check_failed "Cannot reach server IP: $BARRIER_SERVER_IP"
    fi
    
    # Check if barrier port is open
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "$BARRIER_SERVER_IP" "$BARRIER_PORT" >/dev/null 2>&1; then
            check_passed "Barrier port accessible: $BARRIER_SERVER_IP:$BARRIER_PORT"
            ((checks_passed++))
        else
            check_failed "Barrier port not accessible: $BARRIER_SERVER_IP:$BARRIER_PORT"
        fi
    else
        check_warning "netcat not available for port testing"
    fi
    
    # Check local network interface
    if ip route get 1.1.1.1 >/dev/null 2>&1; then
        local local_ip
        local_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
        check_passed "Local network interface working: $local_ip"
        ((checks_passed++))
    else
        check_failed "No network connectivity"
    fi
    
    # Check for firewall interference
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            if ufw status | grep -q "$BARRIER_PORT"; then
                check_passed "Firewall configured for barrier port"
                ((checks_passed++))
            else
                check_warning "Firewall active but barrier port not configured"
            fi
        else
            check_passed "UFW firewall not blocking"
            ((checks_passed++))
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state >/dev/null 2>&1; then
            if firewall-cmd --list-ports | grep -q "$BARRIER_PORT"; then
                check_passed "Firewall configured for barrier port"
                ((checks_passed++))
            else
                check_warning "Firewalld active but barrier port not configured"
            fi
        else
            check_passed "Firewalld not blocking"
            ((checks_passed++))
        fi
    else
        check_passed "No known firewall detected"
        ((checks_passed++))
    fi
    
    echo "Network check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# Display Environment Checks
verify_display_environment() {
    if [ "$VERIFY_DISPLAY" != "true" ]; then
        return 0
    fi
    
    echo -e "${BLUE}🖥️  Checking Display Environment...${NC}"
    
    local checks_passed=0
    local total_checks=4
    
    # Check DISPLAY variable
    if [ -n "${DISPLAY:-}" ]; then
        check_passed "DISPLAY variable set: $DISPLAY"
        ((checks_passed++))
    else
        check_failed "DISPLAY variable not set"
    fi
    
    # Check display server connectivity
    if command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo >/dev/null 2>&1; then
        local screen_info
        screen_info=$(xdpyinfo | grep "dimensions:" | awk '{print $2}' || echo "unknown")
        check_passed "X11 display server accessible: $screen_info"
        ((checks_passed++))
    elif [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        check_passed "Wayland session detected"
        ((checks_passed++))
    else
        check_failed "Cannot connect to display server"
    fi
    
    # Check session type
    local session_type=${XDG_SESSION_TYPE:-unknown}
    case "$session_type" in
        x11)
            check_passed "X11 session detected"
            ((checks_passed++))
            ;;
        wayland)
            check_passed "Wayland session detected"
            ((checks_passed++))
            ;;
        *)
            check_warning "Unknown session type: $session_type"
            ;;
    esac
    
    # Check desktop environment
    local desktop=${XDG_CURRENT_DESKTOP:-unknown}
    if [ "$desktop" != "unknown" ]; then
        check_passed "Desktop environment detected: $desktop"
        ((checks_passed++))
    else
        check_warning "Desktop environment unknown"
    fi
    
    echo "Display check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# Service Status Checks
verify_service_status() {
    echo -e "${BLUE}⚙️  Checking Service Status...${NC}"
    
    local checks_passed=0
    local total_checks=3
    
    # Check systemd service file
    if [ -f "$HOME/.config/systemd/user/barrier-server.service" ]; then
        check_passed "Server service file exists"
        ((checks_passed++))
    else
        check_warning "Server service file not found"
    fi
    
    if [ -f "$HOME/.config/systemd/user/barrier-client.service" ]; then
        check_passed "Client service file exists"
        ((checks_passed++))
    else
        check_warning "Client service file not found"
    fi
    
    # Check running processes
    if pgrep -f "barrier[cs]" >/dev/null 2>&1; then
        local process_info
        process_info=$(pgrep -f "barrier[cs]" | wc -l)
        check_passed "Barrier processes running: $process_info"
        ((checks_passed++))
    else
        check_warning "No barrier processes currently running"
    fi
    
    echo "Service check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# Configuration Validation
verify_configuration() {
    echo -e "${BLUE}📋 Checking Configuration...${NC}"
    
    local checks_passed=0
    local total_checks=3
    
    # Check project structure
    if [ -f "$PROJECT_DIR/setup.sh" ] && [ -d "$PROJECT_DIR/server" ] && [ -d "$PROJECT_DIR/client" ]; then
        check_passed "Project structure valid"
        ((checks_passed++))
    else
        check_failed "Invalid project structure"
    fi
    
    # Check flox environment
    if [ -f "$PROJECT_DIR/.flox/env/manifest.toml" ]; then
        check_passed "Flox environment configured"
        ((checks_passed++))
    else
        check_warning "Flox environment not found"
    fi
    
    # Check environment configuration
    if [ -f "$PROJECT_DIR/.env" ]; then
        check_passed "Environment configuration found"
        ((checks_passed++))
    elif [ -f "$PROJECT_DIR/.env.example" ]; then
        check_warning "Only example configuration found - copy to .env"
    else
        check_warning "No environment configuration found"
    fi
    
    echo "Configuration check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# System Dependencies Check
verify_system_dependencies() {
    echo -e "${BLUE}📦 Checking System Dependencies...${NC}"
    
    local checks_passed=0
    local total_checks=0
    local required_commands=("nc" "nmap" "htop" "lsof" "git" "curl")
    
    for cmd in "${required_commands[@]}"; do
        ((total_checks++))
        if command -v "$cmd" >/dev/null 2>&1; then
            check_passed "$cmd available"
            ((checks_passed++))
        else
            check_warning "$cmd not found"
        fi
    done
    
    echo "Dependencies check: $checks_passed/$total_checks passed"
    echo ""
    
    return $((total_checks - checks_passed))
}

# Generate verification report
generate_report() {
    local total_failures=$1
    
    echo -e "${BLUE}📊 Verification Summary${NC}"
    echo "======================="
    
    if [ "$total_failures" -eq 0 ]; then
        echo -e "${GREEN}🎉 All checks passed! Barrier is ready for use.${NC}"
        echo ""
        echo "Next steps:"
        echo "  - Start server: systemctl --user start barrier-server"
        echo "  - Start client: ./client/scripts/start-client.sh"
        echo "  - Check status: ./scripts/status-check.sh"
    elif [ "$total_failures" -le 5 ]; then
        echo -e "${YELLOW}⚠️  Some issues detected but installation is mostly ready.${NC}"
        echo "Address the warnings above for optimal performance."
    else
        echo -e "${RED}❌ Multiple critical issues detected.${NC}"
        echo "Please resolve the failed checks before using Barrier."
        echo ""
        echo "Common solutions:"
        echo "  - Install barrier: sudo apt-get install barrier"
        echo "  - Configure firewall: ./server/configure-firewall.sh"
        echo "  - Set up display: export DISPLAY=:0"
    fi
    
    echo ""
}

# Main execution
main() {
    print_header
    
    local total_failures=0
    
    # Run all verification checks
    verify_barrier_installation || ((total_failures += $?))
    verify_network_connectivity || ((total_failures += $?))
    verify_display_environment || ((total_failures += $?))
    verify_service_status || ((total_failures += $?))
    verify_configuration || ((total_failures += $?))
    verify_system_dependencies || ((total_failures += $?))
    
    generate_report "$total_failures"
    
    # Return appropriate exit code
    if [ "$total_failures" -eq 0 ]; then
        return 0
    elif [ "$total_failures" -le 5 ]; then
        return 1  # Warnings
    else
        return 2  # Critical failures
    fi
}

# Command line argument processing
case "${1:-verify}" in
    "verify"|"")
        main
        ;;
    "network")
        print_header
        verify_network_connectivity
        ;;
    "display")
        print_header
        verify_display_environment
        ;;
    "config")
        print_header
        verify_configuration
        ;;
    "deps")
        print_header
        verify_system_dependencies
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [check]"
        echo ""
        echo "Checks:"
        echo "  verify (default) - Run all verification checks"
        echo "  network         - Check network connectivity only"
        echo "  display         - Check display environment only"
        echo "  config          - Check configuration only"
        echo "  deps            - Check system dependencies only"
        echo ""
        echo "Environment variables:"
        echo "  VERBOSE=true    - Enable verbose output"
        echo "  EXIT_ON_FAILURE=true - Exit immediately on first failure"
        echo "  VERIFY_NETWORK=false - Skip network checks"
        echo "  VERIFY_DISPLAY=false - Skip display checks"
        ;;
    *)
        echo "Unknown check: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac