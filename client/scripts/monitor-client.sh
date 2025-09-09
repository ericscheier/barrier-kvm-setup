#!/bin/bash

# Barrier Client Monitoring Script
# Monitors client process and restarts if it hangs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Configuration
MONITOR_INTERVAL=30  # Check every 30 seconds
MAX_HANG_TIME=120    # Consider hung if no activity for 2 minutes
RESTART_LIMIT=5      # Maximum restarts per session

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Barrier Client Monitor ===${NC}"
echo "Monitor interval: ${MONITOR_INTERVAL}s"
echo "Hang detection: ${MAX_HANG_TIME}s"
echo "Max restarts: $RESTART_LIMIT"
echo

restart_count=0
last_log_size=0

cleanup() {
    echo -e "\n${YELLOW}Stopping monitor...${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

while true; do
    # Check if barrierc is running
    if pgrep -x "barrierc" > /dev/null; then
        # Check log activity to detect hangs
        log_file="$LOG_DIR/client.log"
        
        if [ -f "$log_file" ]; then
            current_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
            
            if [ "$current_size" -eq "$last_log_size" ]; then
                echo -e "${YELLOW}[$(date)] No log activity detected - client may be hanging${NC}"
                
                # Check if process is actually responsive
                if kill -0 "$(pgrep -x barrierc)" 2>/dev/null; then
                    echo -e "${RED}[$(date)] Client appears hung - restarting...${NC}"
                    
                    # Kill hung process
                    pkill -x barrierc
                    sleep 3
                    
                    # Restart if we haven't hit the limit
                    if [ $restart_count -lt $RESTART_LIMIT ]; then
                        echo -e "${BLUE}[$(date)] Restarting client (attempt $((restart_count + 1))/${RESTART_LIMIT})...${NC}"
                        
                        # Start in background
                        nohup "$SCRIPT_DIR/start-client.sh" > "$LOG_DIR/monitor-restart.log" 2>&1 &
                        
                        restart_count=$((restart_count + 1))
                    else
                        echo -e "${RED}[$(date)] Max restart limit reached - manual intervention required${NC}"
                        break
                    fi
                fi
            else
                echo -e "${GREEN}[$(date)] Client active (log size: $current_size)${NC}"
                last_log_size=$current_size
            fi
        else
            echo -e "${YELLOW}[$(date)] Log file not found - client may not be running properly${NC}"
        fi
    else
        echo -e "${RED}[$(date)] Client not running${NC}"
        
        if [ $restart_count -lt $RESTART_LIMIT ]; then
            echo -e "${BLUE}[$(date)] Starting client (attempt $((restart_count + 1))/${RESTART_LIMIT})...${NC}"
            nohup "$SCRIPT_DIR/start-client.sh" > "$LOG_DIR/monitor-restart.log" 2>&1 &
            restart_count=$((restart_count + 1))
        else
            echo -e "${RED}[$(date)] Max restart limit reached - stopping monitor${NC}"
            break
        fi
    fi
    
    sleep $MONITOR_INTERVAL
done

echo -e "${BLUE}Monitor stopped${NC}"