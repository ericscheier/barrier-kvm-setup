#!/bin/bash

# Barrier Auto-Recovery System for Multi-Client Scenarios
# Monitors and automatically recovers from common failure scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
RECOVERY_LOG="$PROJECT_DIR/logs/auto-recovery.log"
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
MAX_RECOVERY_ATTEMPTS=${MAX_RECOVERY_ATTEMPTS:-3}
RECOVERY_COOLDOWN=${RECOVERY_COOLDOWN:-300}
ENABLE_NOTIFICATIONS=${ENABLE_NOTIFICATIONS:-true}

# Recovery state tracking
RECOVERY_STATE_FILE="$PROJECT_DIR/.recovery-state"
LAST_RECOVERY_FILE="$PROJECT_DIR/.last-recovery"

# Expected clients
EXPECTED_CLIENTS=${EXPECTED_CLIENTS:-"wright orville"}

# Load environment configuration
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" || true
fi
if [ -f "$PROJECT_DIR/.env.3machines" ]; then
    source "$PROJECT_DIR/.env.3machines" || true
fi

# Create required directories
mkdir -p "$PROJECT_DIR/logs"
touch "$RECOVERY_LOG"

print_header() {
    echo -e "${BLUE}🔄 Barrier Auto-Recovery System${NC}"
    echo "=================================="
    echo "Host: $(hostname)"
    echo "Expected Clients: $EXPECTED_CLIENTS"
    echo "Check Interval: ${CHECK_INTERVAL}s"
    echo "Time: $(date)"
    echo ""
}

log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$RECOVERY_LOG"
}

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if [ "$ENABLE_NOTIFICATIONS" = "true" ] && command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" --urgency="$urgency" --app-name="Barrier Recovery" 2>/dev/null || true
    fi
}

get_recovery_attempts() {
    local failure_type="$1"
    if [ -f "$RECOVERY_STATE_FILE" ]; then
        grep "^$failure_type:" "$RECOVERY_STATE_FILE" 2>/dev/null | cut -d':' -f2 || echo "0"
    else
        echo "0"
    fi
}

update_recovery_attempts() {
    local failure_type="$1"
    local attempts="$2"
    
    # Create state file if it doesn't exist
    touch "$RECOVERY_STATE_FILE"
    
    # Update or add entry
    if grep -q "^$failure_type:" "$RECOVERY_STATE_FILE"; then
        sed -i "s/^$failure_type:.*/$failure_type:$attempts/" "$RECOVERY_STATE_FILE"
    else
        echo "$failure_type:$attempts" >> "$RECOVERY_STATE_FILE"
    fi
}

reset_recovery_attempts() {
    local failure_type="$1"
    update_recovery_attempts "$failure_type" "0"
}

check_recovery_cooldown() {
    if [ -f "$LAST_RECOVERY_FILE" ]; then
        local last_recovery
        last_recovery=$(cat "$LAST_RECOVERY_FILE" 2>/dev/null || echo "0")
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - last_recovery))
        
        if [ "$elapsed" -lt "$RECOVERY_COOLDOWN" ]; then
            local remaining=$((RECOVERY_COOLDOWN - elapsed))
            log_event "INFO" "Recovery cooldown active: ${remaining}s remaining"
            return 1
        fi
    fi
    return 0
}

record_recovery_attempt() {
    date +%s > "$LAST_RECOVERY_FILE"
}

# Check if server is running and healthy
check_server_health() {
    # Check if systemd service is active
    if ! systemctl --user is-active barrier-server >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if process is actually running
    if ! pgrep -f "barriers.*--name.*$(hostname)" >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if port is listening
    if ! ss -tlnp | grep -q ":${BARRIER_PORT:-24800} "; then
        return 1
    fi
    
    return 0
}

# Recover server failure
recover_server() {
    local attempts
    attempts=$(get_recovery_attempts "server")
    
    if [ "$attempts" -ge "$MAX_RECOVERY_ATTEMPTS" ]; then
        log_event "ERROR" "Server recovery max attempts ($MAX_RECOVERY_ATTEMPTS) reached"
        send_notification "Barrier Recovery" "Server recovery failed after $MAX_RECOVERY_ATTEMPTS attempts" "critical"
        return 1
    fi
    
    if ! check_recovery_cooldown; then
        return 1
    fi
    
    log_event "WARN" "Attempting server recovery (attempt $((attempts + 1))/$MAX_RECOVERY_ATTEMPTS)"
    send_notification "Barrier Recovery" "Attempting to recover server" "normal"
    
    # Kill any hanging processes
    pkill -f barriers 2>/dev/null || true
    sleep 2
    
    # Restart service
    systemctl --user restart barrier-server
    sleep 5
    
    # Update recovery attempts
    update_recovery_attempts "server" "$((attempts + 1))"
    record_recovery_attempt
    
    # Check if recovery was successful
    if check_server_health; then
        log_event "INFO" "Server recovery successful"
        send_notification "Barrier Recovery" "Server recovery successful" "normal"
        reset_recovery_attempts "server"
        return 0
    else
        log_event "ERROR" "Server recovery failed"
        return 1
    fi
}

# Check connected clients
get_connected_clients() {
    # Check recent logs for connected clients
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --user -u barrier-server --since "2 minutes ago" --no-pager 2>/dev/null | \
        grep -o 'client "[^"]*" has connected' | \
        sed 's/client "\([^"]*\)" has connected/\1/' | \
        sort -u
    else
        # Fallback: check server logs if available
        if [ -f "$PROJECT_DIR/logs/server.log" ]; then
            tail -100 "$PROJECT_DIR/logs/server.log" 2>/dev/null | \
            grep -o 'client "[^"]*" has connected' | \
            sed 's/client "\([^"]*\)" has connected/\1/' | \
            sort -u
        fi
    fi
}

# Check for disconnected clients
check_client_connectivity() {
    local connected_clients
    connected_clients=$(get_connected_clients)
    local disconnected_clients=""
    
    for expected_client in $EXPECTED_CLIENTS; do
        if ! echo "$connected_clients" | grep -q "^$expected_client$"; then
            disconnected_clients="$disconnected_clients $expected_client"
        fi
    done
    
    if [ -n "$disconnected_clients" ]; then
        echo "$disconnected_clients"
        return 1
    else
        return 0
    fi
}

# Recover client connectivity issues
recover_client_connectivity() {
    local disconnected_clients="$1"
    local attempts
    attempts=$(get_recovery_attempts "client")
    
    if [ "$attempts" -ge "$MAX_RECOVERY_ATTEMPTS" ]; then
        log_event "ERROR" "Client recovery max attempts ($MAX_RECOVERY_ATTEMPTS) reached"
        send_notification "Barrier Recovery" "Client recovery failed after $MAX_RECOVERY_ATTEMPTS attempts" "critical"
        return 1
    fi
    
    if ! check_recovery_cooldown; then
        return 1
    fi
    
    log_event "WARN" "Client connectivity issues detected: $disconnected_clients"
    log_event "INFO" "Attempting client recovery (attempt $((attempts + 1))/$MAX_RECOVERY_ATTEMPTS)"
    send_notification "Barrier Recovery" "Attempting to recover client connections" "normal"
    
    # Try to restart server to allow clients to reconnect
    systemctl --user restart barrier-server
    sleep 10
    
    # Update recovery attempts
    update_recovery_attempts "client" "$((attempts + 1))"
    record_recovery_attempt
    
    # Wait a bit more for clients to reconnect
    sleep 5
    
    # Check if recovery was successful
    local still_disconnected
    if still_disconnected=$(check_client_connectivity); then
        log_event "INFO" "Client connectivity recovery successful"
        send_notification "Barrier Recovery" "Client connectivity restored" "normal"
        reset_recovery_attempts "client"
        return 0
    else
        log_event "WARN" "Some clients still disconnected: $still_disconnected"
        return 1
    fi
}

# Check for port conflicts
check_port_conflicts() {
    local port="${BARRIER_PORT:-24800}"
    local listening_processes
    listening_processes=$(ss -tlnp | grep ":$port " | wc -l)
    
    if [ "$listening_processes" -gt 1 ]; then
        log_event "WARN" "Multiple processes listening on port $port"
        return 1
    elif [ "$listening_processes" -eq 0 ]; then
        log_event "WARN" "No process listening on port $port"
        return 1
    fi
    
    return 0
}

# Recover port conflicts
recover_port_conflicts() {
    local attempts
    attempts=$(get_recovery_attempts "port")
    
    if [ "$attempts" -ge "$MAX_RECOVERY_ATTEMPTS" ]; then
        log_event "ERROR" "Port recovery max attempts ($MAX_RECOVERY_ATTEMPTS) reached"
        return 1
    fi
    
    log_event "INFO" "Attempting port conflict recovery (attempt $((attempts + 1))/$MAX_RECOVERY_ATTEMPTS)"
    
    # Kill all barrier processes
    pkill -f barriers 2>/dev/null || true
    sleep 3
    
    # Start fresh
    systemctl --user start barrier-server
    sleep 5
    
    update_recovery_attempts "port" "$((attempts + 1))"
    record_recovery_attempt
    
    if check_port_conflicts; then
        log_event "INFO" "Port conflict recovery successful"
        reset_recovery_attempts "port"
        return 0
    else
        log_event "ERROR" "Port conflict recovery failed"
        return 1
    fi
}

# Check system resources
check_system_resources() {
    # Check memory usage
    local memory_usage
    memory_usage=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
    local memory_threshold=90
    
    if [ "${memory_usage%.*}" -gt "$memory_threshold" ]; then
        log_event "WARN" "High memory usage: ${memory_usage}%"
        return 1
    fi
    
    # Check load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_threshold=4
    
    if [ "${load_avg%.*}" -gt "$load_threshold" ] 2>/dev/null; then
        log_event "WARN" "High system load: $load_avg"
        return 1
    fi
    
    return 0
}

# Perform health check and recovery
perform_health_check() {
    local issues_found=false
    local recovery_needed=false
    
    log_event "INFO" "Performing health check..."
    
    # 1. Check server health
    if ! check_server_health; then
        log_event "ERROR" "Server health check failed"
        issues_found=true
        
        if recover_server; then
            recovery_needed=true
        fi
    else
        # Reset server recovery attempts on success
        reset_recovery_attempts "server"
    fi
    
    # 2. Check client connectivity (only if server is healthy)
    if check_server_health; then
        local disconnected_clients
        if disconnected_clients=$(check_client_connectivity); then
            if [ -n "$disconnected_clients" ]; then
                log_event "WARN" "Client connectivity issues: $disconnected_clients"
                issues_found=true
                
                if recover_client_connectivity "$disconnected_clients"; then
                    recovery_needed=true
                fi
            fi
        else
            # Reset client recovery attempts on success
            reset_recovery_attempts "client"
        fi
    fi
    
    # 3. Check for port conflicts
    if ! check_port_conflicts; then
        log_event "WARN" "Port conflict detected"
        issues_found=true
        
        if recover_port_conflicts; then
            recovery_needed=true
        fi
    else
        reset_recovery_attempts "port"
    fi
    
    # 4. Check system resources (warning only, no recovery)
    if ! check_system_resources; then
        issues_found=true
    fi
    
    if [ "$issues_found" = "false" ]; then
        log_event "INFO" "All health checks passed"
    elif [ "$recovery_needed" = "true" ]; then
        log_event "INFO" "Recovery actions taken"
    fi
}

# Main monitoring loop
monitor_loop() {
    log_event "INFO" "Starting auto-recovery monitoring"
    send_notification "Barrier Recovery" "Auto-recovery system started" "low"
    
    while true; do
        perform_health_check
        sleep "$CHECK_INTERVAL"
    done
}

# Generate recovery report
generate_recovery_report() {
    echo -e "${BLUE}📊 Recovery System Status${NC}"
    echo "========================="
    echo "Recovery Log: $RECOVERY_LOG"
    echo ""
    
    if [ -f "$RECOVERY_STATE_FILE" ]; then
        echo "Recovery Attempts:"
        while IFS=':' read -r failure_type attempts; do
            echo "  $failure_type: $attempts"
        done < "$RECOVERY_STATE_FILE"
    else
        echo "No recovery attempts recorded"
    fi
    
    echo ""
    echo "Recent Events (last 10):"
    tail -10 "$RECOVERY_LOG" 2>/dev/null || echo "No recent events"
}

# Command line help
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --monitor               Start monitoring loop (default)"
    echo "  --check-once            Perform single health check"
    echo "  --report                Show recovery status report"
    echo "  --reset-attempts        Reset all recovery attempt counters"
    echo "  --interval SECONDS      Check interval (default: $CHECK_INTERVAL)"
    echo ""
    echo "Environment variables:"
    echo "  CHECK_INTERVAL=$CHECK_INTERVAL"
    echo "  MAX_RECOVERY_ATTEMPTS=$MAX_RECOVERY_ATTEMPTS"
    echo "  RECOVERY_COOLDOWN=$RECOVERY_COOLDOWN"
    echo "  EXPECTED_CLIENTS=\"$EXPECTED_CLIENTS\""
    echo "  ENABLE_NOTIFICATIONS=$ENABLE_NOTIFICATIONS"
}

# Signal handlers
cleanup() {
    echo ""
    log_event "INFO" "Auto-recovery monitoring stopped"
    send_notification "Barrier Recovery" "Auto-recovery system stopped" "low"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
main() {
    local mode="monitor"
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --monitor)
                mode="monitor"
                shift
                ;;
            --check-once)
                mode="check"
                shift
                ;;
            --report)
                mode="report"
                shift
                ;;
            --reset-attempts)
                mode="reset"
                shift
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
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
    
    case "$mode" in
        monitor)
            print_header
            monitor_loop
            ;;
        check)
            print_header
            perform_health_check
            ;;
        report)
            generate_recovery_report
            ;;
        reset)
            echo "Resetting recovery attempt counters..."
            rm -f "$RECOVERY_STATE_FILE"
            log_event "INFO" "Recovery attempt counters reset"
            echo "Done."
            ;;
        *)
            echo "Unknown mode: $mode"
            return 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"