#!/bin/bash

# Multi-Client Barrier Monitoring Script
# Monitor multiple client connections and provide status dashboard

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
MONITOR_INTERVAL=${MONITOR_INTERVAL:-5}
LOG_FILE="$PROJECT_DIR/logs/multi-client-monitor.log"
ALERT_DISCONNECTIONS=${ALERT_DISCONNECTIONS:-true}

# Expected clients (can be overridden by environment)
EXPECTED_CLIENTS=${EXPECTED_CLIENTS:-"wright orville"}

# Load environment configuration
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" || true
fi

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

print_header() {
    clear
    echo -e "${BLUE}🖥️  Barrier Multi-Client Monitor${NC}"
    echo "=================================="
    echo "Server: $(hostname)"
    echo "Expected Clients: $EXPECTED_CLIENTS"
    echo "Update Interval: ${MONITOR_INTERVAL}s"
    echo "Time: $(date)"
    echo ""
}

log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

get_server_status() {
    if systemctl --user is-active barrier-server >/dev/null 2>&1; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

get_server_pid() {
    pgrep -f "barriers.*--name.*$(hostname)" | head -1 || echo ""
}

get_connected_clients() {
    local log_output
    if log_output=$(journalctl --user -u barrier-server --since "1 minute ago" --no-pager 2>/dev/null); then
        # Look for recent connection messages
        echo "$log_output" | grep -o 'client "[^"]*" has connected' | sed 's/client "\([^"]*\)" has connected/\1/' | sort -u
    else
        # Fallback: check recent server logs
        if [ -f "$PROJECT_DIR/logs/server.log" ]; then
            tail -50 "$PROJECT_DIR/logs/server.log" 2>/dev/null | grep -o 'client "[^"]*" has connected' | sed 's/client "\([^"]*\)" has connected/\1/' | sort -u
        fi
    fi
}

get_recent_activity() {
    local client="$1"
    local activity=""
    
    # Check for recent switching activity
    if activity=$(journalctl --user -u barrier-server --since "30 seconds ago" --no-pager 2>/dev/null | grep -i "switch.*$client" | tail -1); then
        local timestamp
        timestamp=$(echo "$activity" | awk '{print $1, $2, $3}')
        echo "Active ($timestamp)"
    else
        echo "Idle"
    fi
}

check_client_status() {
    local client="$1"
    local connected_clients="$2"
    
    if echo "$connected_clients" | grep -q "^$client$"; then
        echo -e "${GREEN}✅ CONNECTED${NC}"
        return 0
    else
        echo -e "${RED}❌ DISCONNECTED${NC}"
        return 1
    fi
}

get_server_uptime() {
    local pid="$1"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        local start_time
        start_time=$(ps -o lstart= -p "$pid" 2>/dev/null | xargs -0 date -d 2>/dev/null || echo "unknown")
        if [ "$start_time" != "unknown" ]; then
            local now
            now=$(date +%s)
            local start_epoch
            start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
            local uptime_seconds=$((now - start_epoch))
            
            if [ "$uptime_seconds" -gt 86400 ]; then
                printf "%dd %02dh %02dm" $((uptime_seconds / 86400)) $(((uptime_seconds % 86400) / 3600)) $(((uptime_seconds % 3600) / 60))
            elif [ "$uptime_seconds" -gt 3600 ]; then
                printf "%dh %02dm" $((uptime_seconds / 3600)) $(((uptime_seconds % 3600) / 60))
            else
                printf "%dm %02ds" $((uptime_seconds / 60)) $((uptime_seconds % 60))
            fi
        else
            echo "unknown"
        fi
    else
        echo "not running"
    fi
}

get_network_stats() {
    local port="${BARRIER_PORT:-24800}"
    local connections
    connections=$(ss -tn | grep ":$port" | wc -l 2>/dev/null || echo "0")
    echo "Port $port: $connections connections"
}

get_system_load() {
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    echo "Load: $load"
}

show_client_dashboard() {
    local server_status="$1"
    local server_pid="$2"
    local connected_clients="$3"
    
    echo -e "${PURPLE}📊 Server Status${NC}"
    echo "=================="
    
    if [ "$server_status" = "RUNNING" ]; then
        echo -e "Status: ${GREEN}✅ $server_status${NC} (PID: $server_pid)"
        echo "Uptime: $(get_server_uptime "$server_pid")"
    else
        echo -e "Status: ${RED}❌ $server_status${NC}"
    fi
    
    echo "$(get_network_stats)"
    echo "$(get_system_load)"
    echo ""
    
    echo -e "${PURPLE}👥 Client Status${NC}"
    echo "================="
    
    local all_connected=true
    for client in $EXPECTED_CLIENTS; do
        local status
        local activity=""
        
        if ! status=$(check_client_status "$client" "$connected_clients"); then
            all_connected=false
        fi
        
        if echo "$connected_clients" | grep -q "^$client$"; then
            activity=$(get_recent_activity "$client")
        fi
        
        printf "%-12s %s" "$client:" "$status"
        if [ -n "$activity" ]; then
            echo " - $activity"
        else
            echo ""
        fi
    done
    
    echo ""
    
    # Show unexpected clients
    local unexpected_clients=""
    while IFS= read -r client; do
        if [ -n "$client" ]; then
            local expected=false
            for expected_client in $EXPECTED_CLIENTS; do
                if [ "$client" = "$expected_client" ]; then
                    expected=true
                    break
                fi
            done
            if [ "$expected" = "false" ]; then
                unexpected_clients="$unexpected_clients $client"
            fi
        fi
    done <<< "$connected_clients"
    
    if [ -n "$unexpected_clients" ]; then
        echo -e "${YELLOW}⚠️  Unexpected clients:$unexpected_clients${NC}"
        echo ""
    fi
    
    # Overall status
    if [ "$server_status" = "RUNNING" ] && [ "$all_connected" = "true" ]; then
        echo -e "${GREEN}🎉 All systems operational${NC}"
    elif [ "$server_status" = "RUNNING" ]; then
        echo -e "${YELLOW}⚠️  Server running but some clients disconnected${NC}"
    else
        echo -e "${RED}❌ Server not running${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📝 Recent Activity${NC}"
    echo "=================="
    
    # Show recent switching activity
    local recent_logs
    if recent_logs=$(journalctl --user -u barrier-server --since "2 minutes ago" --no-pager 2>/dev/null | grep -E "(switch from|switch to|connected|disconnected)" | tail -5); then
        echo "$recent_logs" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  No recent activity"
    fi
}

monitor_loop() {
    local iteration=0
    local last_client_state=""
    
    while true; do
        local server_status
        local server_pid
        local connected_clients
        
        server_status=$(get_server_status)
        server_pid=$(get_server_pid)
        connected_clients=$(get_connected_clients)
        
        # Log state changes
        local current_client_state="$server_status:$connected_clients"
        if [ "$current_client_state" != "$last_client_state" ]; then
            log_event "INFO" "State change - Server: $server_status, Clients: $(echo $connected_clients | tr '\n' ' ')"
            last_client_state="$current_client_state"
            
            # Alert on disconnections
            if [ "$ALERT_DISCONNECTIONS" = "true" ]; then
                for client in $EXPECTED_CLIENTS; do
                    if ! echo "$connected_clients" | grep -q "^$client$"; then
                        log_event "ALERT" "Client '$client' disconnected"
                        # Could add desktop notification here
                        # notify-send "Barrier Alert" "Client '$client' disconnected" --urgency=normal
                    fi
                done
            fi
        fi
        
        # Display dashboard
        print_header
        show_client_dashboard "$server_status" "$server_pid" "$connected_clients"
        
        echo ""
        echo -e "${BLUE}Controls:${NC} Ctrl+C to exit | Logs: $LOG_FILE"
        echo "Iteration: $((++iteration)) | Next update in ${MONITOR_INTERVAL}s..."
        
        sleep "$MONITOR_INTERVAL"
    done
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --interval SECONDS    Monitor interval (default: $MONITOR_INTERVAL)"
    echo "  --clients \"CLIENT1 CLIENT2\"  Expected clients (default: \"$EXPECTED_CLIENTS\")"
    echo "  --no-alerts          Disable disconnection alerts"
    echo "  --log-file FILE       Log file location (default: $LOG_FILE)"
    echo ""
    echo "Environment variables:"
    echo "  MONITOR_INTERVAL=$MONITOR_INTERVAL"
    echo "  EXPECTED_CLIENTS=\"$EXPECTED_CLIENTS\""
    echo "  ALERT_DISCONNECTIONS=$ALERT_DISCONNECTIONS"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Monitor wright and orville"
    echo "  $0 --interval 10 --clients \"client1 client2 client3\""
    echo "  $0 --no-alerts                       # Monitor without notifications"
}

# Signal handlers
cleanup() {
    echo ""
    echo "Monitoring stopped."
    log_event "INFO" "Monitoring session ended"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
main() {
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            --clients)
                EXPECTED_CLIENTS="$2"
                shift 2
                ;;
            --no-alerts)
                ALERT_DISCONNECTIONS=false
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
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
    
    log_event "INFO" "Starting multi-client monitoring session"
    log_event "INFO" "Expected clients: $EXPECTED_CLIENTS"
    
    monitor_loop
}

# Run main function with all arguments
main "$@"