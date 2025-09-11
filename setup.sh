#!/bin/bash

# Barrier KVM Setup - Unified Server/Client Setup
# Detects role and runs appropriate setup
# Enhanced with polyglot-workbench integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment configuration if available
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env" || true
elif [ -f "$SCRIPT_DIR/.env.example" ]; then
    # Use example as fallback for new installations
    source "$SCRIPT_DIR/.env.example" 2>/dev/null || true
fi

echo -e "${BLUE}=== Barrier KVM Setup ===${NC}"
echo

# Enhanced role detection with polyglot-workbench support
detect_role() {
    local role=""
    
    # 1. Check command line argument first
    if [ -n "${1:-}" ]; then
        role="$1"
        echo -e "${BLUE}Role specified via command line: $role${NC}"
        return
    fi
    
    # 2. Check polyglot-workbench activation environment
    if [[ "${POLYGLOT_ACTIVATION:-}" == "true" ]]; then
        echo -e "${BLUE}Polyglot-workbench activation detected${NC}"
        
        # Check explicit role setting
        if [ -n "${BARRIER_ROLE:-}" ]; then
            role="${BARRIER_ROLE}"
            echo -e "${BLUE}Role from BARRIER_ROLE environment: $role${NC}"
            return
        fi
        
        # Auto-detect based on hostname patterns if enabled
        if [[ "${POLYGLOT_AUTO_DETECT_ROLE:-false}" == "true" ]]; then
            local hostname=$(hostname)
            local server_patterns="${SERVER_HOSTNAME_PATTERNS:-server,main,host,primary}"
            local client_patterns="${CLIENT_HOSTNAME_PATTERNS:-client,laptop,mobile,secondary}"
            
            # Check server patterns
            IFS=',' read -ra PATTERNS <<< "$server_patterns"
            for pattern in "${PATTERNS[@]}"; do
                if [[ "$hostname" == *"$pattern"* ]]; then
                    role="server"
                    echo -e "${BLUE}Auto-detected role from hostname '$hostname': $role${NC}"
                    return
                fi
            done
            
            # Check client patterns
            IFS=',' read -ra PATTERNS <<< "$client_patterns"
            for pattern in "${PATTERNS[@]}"; do
                if [[ "$hostname" == *"$pattern"* ]]; then
                    role="client"
                    echo -e "${BLUE}Auto-detected role from hostname '$hostname': $role${NC}"
                    return
                fi
            done
        fi
        
        # Default role for polyglot-workbench if no detection
        role="${BARRIER_ROLE:-client}"
        echo -e "${BLUE}Using default polyglot-workbench role: $role${NC}"
        return
    fi
    
    # 3. Check environment variable fallback
    if [ -n "${BARRIER_ROLE:-}" ]; then
        role="${BARRIER_ROLE}"
        echo -e "${BLUE}Role from BARRIER_ROLE environment: $role${NC}"
        return
    fi
    
    # 4. Interactive prompt as fallback
    echo "No role specified. Please specify role:"
    echo "  ./setup.sh server   - Setup as Barrier server"
    echo "  ./setup.sh client   - Setup as Barrier client"
    echo
    echo "Environment variables for automation:"
    echo "  BARRIER_ROLE=server ./setup.sh"
    echo "  POLYGLOT_ACTIVATION=true BARRIER_ROLE=client ./setup.sh"
    echo
    exit 1
}

# Detect role using enhanced logic
detect_role "${1:-}"
ROLE="$role"

# Validate role
if [[ "$ROLE" != "server" && "$ROLE" != "client" ]]; then
    echo -e "${RED}Error: Invalid role '$ROLE'. Must be 'server' or 'client'${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up as: $ROLE${NC}"
echo

# Activate flox environment if available
if [ -f "$SCRIPT_DIR/.flox/env/manifest.toml" ] && command -v flox >/dev/null 2>&1; then
    echo "Activating flox environment..."
    # Note: This script should be run within flox activate
    if [ -z "${FLOX_ENV:-}" ]; then
        echo -e "${YELLOW}Warning: Not in flox environment. Run 'flox activate' first.${NC}"
    fi
fi

# Run role-specific setup
case $ROLE in
    "server")
        echo -e "${BLUE}Running server setup...${NC}"
        cd "$SCRIPT_DIR"
        ./server/setup.sh
        echo
        echo -e "${GREEN}Server setup complete!${NC}"
        echo
        echo "Next steps:"
        echo "1. Configure firewall: ./server/configure-firewall.sh"
        echo "2. Install service: ./server/install-service.sh"
        echo "3. Start server: barriers -f --no-tray --debug INFO --name \$(hostname) --config ~/.barrier/barrier.conf"
        ;;
    "client")
        echo -e "${BLUE}Running client setup...${NC}"
        cd "$SCRIPT_DIR"
        ./client/scripts/setup-client.sh
        echo
        echo -e "${GREEN}Client setup complete!${NC}"
        echo
        echo "Next steps:"
        echo "1. Start client: ./client/scripts/start-client.sh"
        echo "2. For monitoring: ./client/scripts/monitor-client.sh"
        echo "3. For debugging: ./client/scripts/debug-barrier.sh 192.168.1.206"
        ;;
esac

echo
echo -e "${BLUE}Setup completed for $ROLE mode!${NC}"