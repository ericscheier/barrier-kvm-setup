#!/bin/bash

# Barrier Server Discovery Script
# Automatically discover Barrier servers on the local network

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
BARRIER_PORT=${BARRIER_PORT:-24800}
NETWORK_TIMEOUT=${NETWORK_TIMEOUT:-2}
SCAN_TIMEOUT=${SCAN_TIMEOUT:-10}
VERBOSE=${VERBOSE:-false}
QUICK_SCAN=${QUICK_SCAN:-false}

# Load environment configuration
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" || true
fi

print_header() {
    echo -e "${BLUE}🔍 Barrier Server Discovery${NC}"
    echo "============================"
    echo "Port: $BARRIER_PORT"
    echo "Timeout: ${SCAN_TIMEOUT}s"
    echo ""
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
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

# Get local network ranges to scan
get_network_ranges() {
    local ranges=()
    
    # Get default route interface and network
    local default_route
    default_route=$(ip route | grep '^default' | head -1 | awk '{print $5}' 2>/dev/null || echo "")
    
    if [ -n "$default_route" ]; then
        log_verbose "Using default route interface: $default_route"
        
        # Get network addresses for the default interface
        local networks
        networks=$(ip route | grep "$default_route" | grep -E '192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|10\.' | awk '{print $1}' | grep '/' || true)
        
        for network in $networks; do
            # Skip host routes (individual IPs)
            if [[ "$network" == *"/32" ]]; then
                continue
            fi
            ranges+=("$network")
            log_verbose "Found network range: $network"
        done
    fi
    
    # Fallback to common private network ranges if none found
    if [ ${#ranges[@]} -eq 0 ]; then
        log_warning "No specific network ranges detected, using common private ranges"
        ranges=("192.168.1.0/24" "192.168.0.0/24" "10.0.0.0/24" "172.16.0.0/24")
    fi
    
    printf '%s\n' "${ranges[@]}"
}

# Check if IP has Barrier server running
check_barrier_server() {
    local ip="$1"
    local port="${2:-$BARRIER_PORT}"
    
    log_verbose "Checking $ip:$port"
    
    # Quick port check with netcat
    if command -v nc >/dev/null 2>&1; then
        if timeout "$NETWORK_TIMEOUT" nc -z "$ip" "$port" 2>/dev/null; then
            return 0
        fi
    elif command -v nmap >/dev/null 2>&1; then
        # Fallback to nmap if nc not available
        if nmap -p "$port" --open -T4 "$ip" 2>/dev/null | grep -q "open"; then
            return 0
        fi
    else
        # Last resort: try to connect with bash
        if timeout "$NETWORK_TIMEOUT" bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Get additional server information
get_server_info() {
    local ip="$1"
    local port="${2:-$BARRIER_PORT}"
    
    local info="$ip:$port"
    
    # Try to get hostname
    if command -v nslookup >/dev/null 2>&1; then
        local hostname
        hostname=$(timeout 1 nslookup "$ip" 2>/dev/null | grep -oP 'name = \K[^.]+' | head -1 || echo "")
        if [ -n "$hostname" ]; then
            info="$info ($hostname)"
        fi
    elif command -v dig >/dev/null 2>&1; then
        local hostname
        hostname=$(timeout 1 dig +short -x "$ip" 2>/dev/null | sed 's/\.$//' | head -1 || echo "")
        if [ -n "$hostname" ]; then
            info="$info ($hostname)"
        fi
    fi
    
    echo "$info"
}

# Scan single network range for Barrier servers
scan_network_range() {
    local network="$1"
    local servers_found=()
    
    log_info "Scanning network: $network"
    
    if [ "$QUICK_SCAN" = "true" ]; then
        # Quick scan using nmap if available
        if command -v nmap >/dev/null 2>&1; then
            log_verbose "Using nmap for quick scan"
            local open_hosts
            open_hosts=$(timeout "$SCAN_TIMEOUT" nmap -p "$BARRIER_PORT" --open -T4 "$network" 2>/dev/null | grep -oP '(\d+\.\d+\.\d+\.\d+)(?=.*open)' || true)
            
            for host in $open_hosts; do
                local server_info
                server_info=$(get_server_info "$host")
                servers_found+=("$server_info")
                log_success "Found Barrier server: $server_info"
            done
        else
            log_warning "nmap not available for quick scan, falling back to detailed scan"
            QUICK_SCAN="false"
        fi
    fi
    
    # Detailed scan if quick scan not available or failed
    if [ "$QUICK_SCAN" != "true" ]; then
        log_verbose "Performing detailed scan"
        
        # Extract network base and CIDR
        local network_base
        local cidr
        network_base=$(echo "$network" | cut -d'/' -f1)
        cidr=$(echo "$network" | cut -d'/' -f2)
        
        # For common /24 networks, scan directly
        if [ "$cidr" = "24" ]; then
            local base_ip
            base_ip=$(echo "$network_base" | cut -d'.' -f1-3)
            
            # Scan common host addresses first (faster results)
            local priority_hosts=(1 100 101 102 254 2 3 4 5 10 11 12 20 50)
            local found_any=false
            
            for host_num in "${priority_hosts[@]}"; do
                local test_ip="$base_ip.$host_num"
                if check_barrier_server "$test_ip"; then
                    local server_info
                    server_info=$(get_server_info "$test_ip")
                    servers_found+=("$server_info")
                    log_success "Found Barrier server: $server_info"
                    found_any=true
                fi
            done
            
            # If no servers found in priority hosts, do full scan (if time permits)
            if [ "$found_any" = "false" ]; then
                log_verbose "No servers in priority range, scanning full network..."
                for i in {6..99} {103..253}; do
                    local test_ip="$base_ip.$i"
                    if check_barrier_server "$test_ip"; then
                        local server_info
                        server_info=$(get_server_info "$test_ip")
                        servers_found+=("$server_info")
                        log_success "Found Barrier server: $server_info"
                    fi
                done
            fi
        else
            log_warning "Non-/24 network scanning not optimized, may take longer"
            # For non-/24 networks, rely on nmap if available
            if command -v nmap >/dev/null 2>&1; then
                local open_hosts
                open_hosts=$(timeout "$SCAN_TIMEOUT" nmap -p "$BARRIER_PORT" --open -T4 "$network" 2>/dev/null | grep -oP '(\d+\.\d+\.\d+\.\d+)(?=.*open)' || true)
                
                for host in $open_hosts; do
                    local server_info
                    server_info=$(get_server_info "$host")
                    servers_found+=("$server_info")
                    log_success "Found Barrier server: $server_info"
                done
            fi
        fi
    fi
    
    printf '%s\n' "${servers_found[@]}"
}

# Test connectivity to discovered servers
test_server_connectivity() {
    local server="$1"
    local ip
    ip=$(echo "$server" | cut -d':' -f1)
    local port
    port=$(echo "$server" | cut -d':' -f2 | cut -d' ' -f1)
    
    log_info "Testing connectivity to $server"
    
    # Test basic connectivity
    if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
        log_success "Ping successful to $ip"
    else
        log_warning "Ping failed to $ip"
        return 1
    fi
    
    # Test port connectivity
    if check_barrier_server "$ip" "$port"; then
        log_success "Port $port is open on $ip"
    else
        log_warning "Port $port is not accessible on $ip"
        return 1
    fi
    
    return 0
}

# Update configuration with discovered server
update_config_with_server() {
    local server_ip="$1"
    
    log_info "Updating configuration with server: $server_ip"
    
    # Update .env file if it exists
    if [ -f "$PROJECT_DIR/.env" ]; then
        if grep -q "BARRIER_SERVER_IP=" "$PROJECT_DIR/.env"; then
            sed -i "s/BARRIER_SERVER_IP=.*/BARRIER_SERVER_IP=$server_ip/" "$PROJECT_DIR/.env"
            log_success "Updated BARRIER_SERVER_IP in .env"
        else
            echo "BARRIER_SERVER_IP=$server_ip" >> "$PROJECT_DIR/.env"
            log_success "Added BARRIER_SERVER_IP to .env"
        fi
    elif [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        sed -i "s/BARRIER_SERVER_IP=.*/BARRIER_SERVER_IP=$server_ip/" "$PROJECT_DIR/.env"
        log_success "Created .env with discovered server IP"
    fi
}

# Generate discovery report
generate_discovery_report() {
    local servers=("$@")
    
    echo ""
    echo -e "${BLUE}📊 Discovery Summary${NC}"
    echo "===================="
    
    if [ ${#servers[@]} -eq 0 ]; then
        echo -e "${YELLOW}No Barrier servers found on the network${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  - Ensure Barrier server is running"
        echo "  - Check firewall settings on server"
        echo "  - Verify port $BARRIER_PORT is correct"
        echo "  - Try manual connection: nc -z <server-ip> $BARRIER_PORT"
        return 1
    else
        echo -e "${GREEN}Found ${#servers[@]} Barrier server(s):${NC}"
        for server in "${servers[@]}"; do
            echo "  🖥️  $server"
        done
        
        echo ""
        echo "Next steps:"
        if [ ${#servers[@]} -eq 1 ]; then
            local server_ip
            server_ip=$(echo "${servers[0]}" | cut -d':' -f1)
            echo "  - Connect to server: barrierc -f --no-tray --debug INFO --name client $server_ip"
            echo "  - Auto-update config: $0 --update-config"
        else
            echo "  - Choose server and connect manually"
            echo "  - Update configuration with preferred server IP"
        fi
    fi
}

# Command line help
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --quick              Use quick scan method (nmap required)"
    echo "  --verbose            Enable verbose output"
    echo "  --port PORT          Scan for specific port (default: $BARRIER_PORT)"
    echo "  --timeout SECONDS    Scan timeout (default: $SCAN_TIMEOUT)"
    echo "  --network RANGE      Scan specific network range (e.g., 192.168.1.0/24)"
    echo "  --update-config      Update .env with first discovered server"
    echo "  --test-server IP     Test connectivity to specific server"
    echo ""
    echo "Environment variables:"
    echo "  BARRIER_PORT=$BARRIER_PORT"
    echo "  SCAN_TIMEOUT=$SCAN_TIMEOUT"
    echo "  NETWORK_TIMEOUT=$NETWORK_TIMEOUT"
    echo "  VERBOSE=$VERBOSE"
    echo "  QUICK_SCAN=$QUICK_SCAN"
}

# Main discovery function
discover_servers() {
    local specified_network=""
    local update_config=false
    local test_server=""
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_SCAN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --port)
                BARRIER_PORT="$2"
                shift 2
                ;;
            --timeout)
                SCAN_TIMEOUT="$2"
                shift 2
                ;;
            --network)
                specified_network="$2"
                shift 2
                ;;
            --update-config)
                update_config=true
                shift
                ;;
            --test-server)
                test_server="$2"
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
    
    print_header
    
    # Handle specific test server request
    if [ -n "$test_server" ]; then
        test_server_connectivity "$test_server:$BARRIER_PORT"
        return $?
    fi
    
    local all_servers=()
    
    if [ -n "$specified_network" ]; then
        # Scan specified network only
        local servers
        servers=$(scan_network_range "$specified_network")
        if [ -n "$servers" ]; then
            while IFS= read -r server; do
                all_servers+=("$server")
            done <<< "$servers"
        fi
    else
        # Auto-detect and scan all local networks
        log_info "Auto-detecting network ranges..."
        local networks
        networks=$(get_network_ranges)
        
        while IFS= read -r network; do
            if [ -n "$network" ]; then
                local servers
                servers=$(scan_network_range "$network")
                if [ -n "$servers" ]; then
                    while IFS= read -r server; do
                        all_servers+=("$server")
                    done <<< "$servers"
                fi
            fi
        done <<< "$networks"
    fi
    
    # Remove duplicates
    local unique_servers=()
    for server in "${all_servers[@]}"; do
        if [[ ! " ${unique_servers[@]} " =~ " ${server} " ]]; then
            unique_servers+=("$server")
        fi
    done
    
    # Generate report
    generate_discovery_report "${unique_servers[@]}"
    
    # Update configuration if requested and servers found
    if [ "$update_config" = "true" ] && [ ${#unique_servers[@]} -gt 0 ]; then
        local first_server_ip
        first_server_ip=$(echo "${unique_servers[0]}" | cut -d':' -f1)
        update_config_with_server "$first_server_ip"
    fi
    
    # Return appropriate exit code
    if [ ${#unique_servers[@]} -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Run main function with all arguments
discover_servers "$@"