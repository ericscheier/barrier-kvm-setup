#!/bin/bash

# Barrier Daemon Manager
# Unified daemon mode support for both server and client
# Enhanced for polyglot-workbench integration

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
DAEMON_LOG_DIR="$PROJECT_DIR/logs"
DAEMON_PID_DIR="$PROJECT_DIR/.pids"
STARTUP_TIMEOUT=${STARTUP_TIMEOUT:-30}
VERIFICATION_TIMEOUT=${VERIFICATION_TIMEOUT:-10}

# Load environment configuration
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" || true
fi

# Set defaults from environment or config
BARRIER_SERVER_IP=${BARRIER_SERVER_IP:-"192.168.1.206"}
BARRIER_PORT=${BARRIER_PORT:-24800}
BARRIER_CLIENT_NAME=${BARRIER_CLIENT_NAME:-"client"}
BARRIER_SERVER_NAME=${BARRIER_SERVER_NAME:-"$(hostname)"}
BARRIER_LOG_LEVEL=${BARRIER_LOG_LEVEL:-"INFO"}
DISPLAY=${DISPLAY:-":0"}

print_header() {
    echo -e "${BLUE}🤖 Barrier Daemon Manager${NC}"
    echo "=========================="
    echo "Project: $(basename "$PROJECT_DIR")"
    echo "Time: $(date)"
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

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Ensure required directories exist
setup_directories() {
    mkdir -p "$DAEMON_LOG_DIR"
    mkdir -p "$DAEMON_PID_DIR"
    
    # Ensure log files are writable
    touch "$DAEMON_LOG_DIR/server.log" "$DAEMON_LOG_DIR/client.log" "$DAEMON_LOG_DIR/daemon.log"
}

# Get process ID for a service
get_service_pid() {
    local service="$1"
    local pid_file="$DAEMON_PID_DIR/$service.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        else
            # Clean up stale pid file
            rm -f "$pid_file"
        fi
    fi
    
    # Fallback to process search
    pgrep -f "barrier[sc]" | head -1 || echo ""
}

# Check if service is running
is_service_running() {
    local service="$1"
    local pid
    pid=$(get_service_pid "$service")
    
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Start Barrier server in daemon mode
start_server_daemon() {
    log_info "Starting Barrier server daemon..."
    
    # Check if already running
    if is_service_running "server"; then
        local pid
        pid=$(get_service_pid "server")
        log_warning "Barrier server already running (PID: $pid)"
        return 0
    fi
    
    # Ensure configuration exists
    if [ ! -f "$HOME/.barrier/barrier.conf" ] && [ ! -f "$PROJECT_DIR/server/barrier.conf" ]; then
        log_error "No Barrier server configuration found"
        log_info "Run ./setup.sh server first"
        return 1
    fi
    
    # Copy configuration if needed
    if [ -f "$PROJECT_DIR/server/barrier.conf" ] && [ ! -f "$HOME/.barrier/barrier.conf" ]; then
        mkdir -p "$HOME/.barrier"
        cp "$PROJECT_DIR/server/barrier.conf" "$HOME/.barrier/barrier.conf"
        log_info "Copied server configuration to ~/.barrier/"
    fi
    
    # Start server daemon
    local log_file="$DAEMON_LOG_DIR/server.log"
    local pid_file="$DAEMON_PID_DIR/server.pid"
    
    # Use nohup to detach from terminal
    nohup barriers -f --no-tray --debug "$BARRIER_LOG_LEVEL" --disable-crypto \
        --name "$BARRIER_SERVER_NAME" --config "$HOME/.barrier/barrier.conf" \
        > "$log_file" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$pid_file"
    
    # Wait for startup and verify
    log_info "Waiting for server to start (PID: $pid)..."
    local startup_success=false
    for i in $(seq 1 "$STARTUP_TIMEOUT"); do
        if kill -0 "$pid" 2>/dev/null; then
            # Check if server is listening
            if ss -tlnp | grep -q ":$BARRIER_PORT "; then
                startup_success=true
                break
            fi
        else
            log_error "Server process died during startup"
            break
        fi
        sleep 1
    done
    
    if [ "$startup_success" = "true" ]; then
        log_success "Barrier server started successfully (PID: $pid)"
        log_info "Listening on port $BARRIER_PORT"
        log_info "Log file: $log_file"
        return 0
    else
        log_error "Failed to start Barrier server"
        log_info "Check log file: $log_file"
        return 1
    fi
}

# Start Barrier client in daemon mode
start_client_daemon() {
    log_info "Starting Barrier client daemon..."
    
    # Check if already running
    if is_service_running "client"; then
        local pid
        pid=$(get_service_pid "client")
        log_warning "Barrier client already running (PID: $pid)"
        return 0
    fi
    
    # Verify server is reachable
    log_info "Testing connection to server: $BARRIER_SERVER_IP:$BARRIER_PORT"
    if ! nc -z -w5 "$BARRIER_SERVER_IP" "$BARRIER_PORT" 2>/dev/null; then
        log_warning "Cannot reach server at $BARRIER_SERVER_IP:$BARRIER_PORT"
        log_info "Starting client anyway (will retry connection)..."
    fi
    
    # Start client daemon
    local log_file="$DAEMON_LOG_DIR/client.log"
    local pid_file="$DAEMON_PID_DIR/client.pid"
    
    # Set display environment for daemon
    export DISPLAY="$DISPLAY"
    
    # Use nohup to detach from terminal
    nohup barrierc -f --no-tray --debug "$BARRIER_LOG_LEVEL" --disable-crypto \
        --name "$BARRIER_CLIENT_NAME" "$BARRIER_SERVER_IP" \
        > "$log_file" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$pid_file"
    
    # Wait for startup and verify
    log_info "Waiting for client to start (PID: $pid)..."
    local startup_success=false
    for i in $(seq 1 "$STARTUP_TIMEOUT"); do
        if kill -0 "$pid" 2>/dev/null; then
            # Check log for connection success
            if tail -10 "$log_file" 2>/dev/null | grep -q "connected\|established"; then
                startup_success=true
                break
            fi
        else
            log_error "Client process died during startup"
            break
        fi
        sleep 1
    done
    
    if [ "$startup_success" = "true" ]; then
        log_success "Barrier client started successfully (PID: $pid)"
        log_info "Connected to server: $BARRIER_SERVER_IP:$BARRIER_PORT"
        log_info "Log file: $log_file"
        return 0
    else
        # Client might still be trying to connect
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Client started but not yet connected to server"
            log_info "Monitor connection in log: $log_file"
            return 0
        else
            log_error "Failed to start Barrier client"
            log_info "Check log file: $log_file"
            return 1
        fi
    fi
}

# Stop service daemon
stop_service_daemon() {
    local service="$1"
    local pid
    pid=$(get_service_pid "$service")
    
    if [ -z "$pid" ]; then
        log_info "Barrier $service is not running"
        return 0
    fi
    
    log_info "Stopping Barrier $service (PID: $pid)..."
    
    # Try graceful shutdown first
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown
        for i in $(seq 1 10); do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Graceful shutdown failed, force killing..."
            kill -KILL "$pid" 2>/dev/null || true
        fi
    fi
    
    # Clean up pid file
    rm -f "$DAEMON_PID_DIR/$service.pid"
    
    log_success "Barrier $service stopped"
}

# Show service status
show_service_status() {
    local service="$1"
    local pid
    pid=$(get_service_pid "$service")
    
    echo -e "${BLUE}📊 Barrier $service Status${NC}"
    echo "========================"
    
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log_success "Status: Running (PID: $pid)"
        
        # Show additional info based on service type
        if [ "$service" = "server" ]; then
            if ss -tlnp | grep -q ":$BARRIER_PORT "; then
                log_success "Listening on port: $BARRIER_PORT"
            else
                log_warning "Port not listening: $BARRIER_PORT"
            fi
        elif [ "$service" = "client" ]; then
            log_info "Target server: $BARRIER_SERVER_IP:$BARRIER_PORT"
        fi
        
        # Show recent log entries
        local log_file="$DAEMON_LOG_DIR/$service.log"
        if [ -f "$log_file" ]; then
            echo ""
            echo "Recent log entries:"
            tail -5 "$log_file" 2>/dev/null || echo "No recent logs"
        fi
    else
        log_warning "Status: Not running"
    fi
    
    echo ""
}

# Monitor service health
monitor_service() {
    local service="$1"
    local check_interval="${2:-5}"
    
    log_info "Monitoring $service (Ctrl+C to stop)..."
    
    while true; do
        local pid
        pid=$(get_service_pid "$service")
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "[$timestamp] ✅ $service running (PID: $pid)"
        else
            echo "[$timestamp] ❌ $service not running"
            
            # Auto-restart if configured
            if [ "${AUTO_RESTART_DAEMON:-false}" = "true" ]; then
                log_warning "Auto-restarting $service..."
                if [ "$service" = "server" ]; then
                    start_server_daemon
                elif [ "$service" = "client" ]; then
                    start_client_daemon
                fi
            fi
        fi
        
        sleep "$check_interval"
    done
}

# Polyglot-workbench integration functions
polyglot_start_services() {
    local role="${BARRIER_ROLE:-auto}"
    
    if [ "$role" = "auto" ]; then
        # Try to detect role
        if [ -f "$PROJECT_DIR/server/barrier.conf" ] || [ -f "$HOME/.barrier/barrier.conf" ]; then
            role="server"
        else
            role="client"
        fi
        log_info "Auto-detected role: $role"
    fi
    
    case "$role" in
        server)
            start_server_daemon
            ;;
        client)
            start_client_daemon
            ;;
        both)
            start_server_daemon
            sleep 2
            start_client_daemon
            ;;
        *)
            log_error "Unknown role: $role"
            return 1
            ;;
    esac
}

polyglot_verify_services() {
    local role="${BARRIER_ROLE:-auto}"
    local all_good=true
    
    case "$role" in
        server|auto)
            if ! is_service_running "server"; then
                log_error "Server service not running"
                all_good=false
            else
                log_success "Server service verified"
            fi
            ;;
    esac
    
    case "$role" in
        client|auto)
            if ! is_service_running "client"; then
                log_error "Client service not running"
                all_good=false
            else
                log_success "Client service verified"
            fi
            ;;
    esac
    
    if [ "$all_good" = "true" ]; then
        log_success "All services verified"
        return 0
    else
        return 1
    fi
}

# Command line help
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start <server|client>    Start daemon service"
    echo "  stop <server|client>     Stop daemon service"
    echo "  restart <server|client>  Restart daemon service"
    echo "  status <server|client>   Show service status"
    echo "  monitor <server|client>  Monitor service health"
    echo "  logs <server|client>     Show service logs"
    echo ""
    echo "Polyglot-workbench commands:"
    echo "  polyglot-start          Start services based on BARRIER_ROLE"
    echo "  polyglot-verify         Verify services are running"
    echo "  polyglot-stop           Stop all services"
    echo ""
    echo "Environment variables:"
    echo "  BARRIER_ROLE={server|client|both|auto}"
    echo "  BARRIER_SERVER_IP=$BARRIER_SERVER_IP"
    echo "  BARRIER_PORT=$BARRIER_PORT"
    echo "  STARTUP_TIMEOUT=$STARTUP_TIMEOUT"
    echo "  AUTO_RESTART_DAEMON=true"
}

# Main execution
main() {
    local command="${1:-help}"
    
    # Ensure directories exist
    setup_directories
    
    case "$command" in
        start)
            local service="${2:-}"
            if [ "$service" = "server" ]; then
                print_header
                start_server_daemon
            elif [ "$service" = "client" ]; then
                print_header
                start_client_daemon
            else
                echo "Usage: $0 start <server|client>"
                return 1
            fi
            ;;
        stop)
            local service="${2:-}"
            if [ "$service" = "server" ]; then
                print_header
                stop_service_daemon "server"
            elif [ "$service" = "client" ]; then
                print_header
                stop_service_daemon "client"
            else
                echo "Usage: $0 stop <server|client>"
                return 1
            fi
            ;;
        restart)
            local service="${2:-}"
            if [ "$service" = "server" ]; then
                print_header
                stop_service_daemon "server"
                sleep 2
                start_server_daemon
            elif [ "$service" = "client" ]; then
                print_header
                stop_service_daemon "client"
                sleep 2
                start_client_daemon
            else
                echo "Usage: $0 restart <server|client>"
                return 1
            fi
            ;;
        status)
            local service="${2:-}"
            if [ "$service" = "server" ] || [ "$service" = "client" ]; then
                show_service_status "$service"
            else
                echo "Usage: $0 status <server|client>"
                return 1
            fi
            ;;
        monitor)
            local service="${2:-}"
            if [ "$service" = "server" ] || [ "$service" = "client" ]; then
                monitor_service "$service" "${3:-5}"
            else
                echo "Usage: $0 monitor <server|client> [interval]"
                return 1
            fi
            ;;
        logs)
            local service="${2:-}"
            if [ "$service" = "server" ] || [ "$service" = "client" ]; then
                local log_file="$DAEMON_LOG_DIR/$service.log"
                if [ -f "$log_file" ]; then
                    tail -f "$log_file"
                else
                    log_error "Log file not found: $log_file"
                    return 1
                fi
            else
                echo "Usage: $0 logs <server|client>"
                return 1
            fi
            ;;
        polyglot-start)
            print_header
            polyglot_start_services
            ;;
        polyglot-verify)
            polyglot_verify_services
            ;;
        polyglot-stop)
            print_header
            stop_service_daemon "server"
            stop_service_daemon "client"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            return 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"