# Barrier KVM Setup

**Status**: Active

A unified, reproducible setup for Barrier KVM/peripheral sharing on Linux. Supports both server and client configurations with focus on reliability and anti-hanging measures.

## Overview

Barrier allows sharing mouse, keyboard and clipboard between multiple machines over network. This repository provides both server and client setups with comprehensive debugging and monitoring tools.

## Project Structure

```
barrier/
├── README.md                   # This file
├── client/                     # Client-specific files
│   ├── configs/               # Client configurations  
│   ├── scripts/               # Client setup and management
│   └── docs/                  # Client troubleshooting
├── server/                     # Server-specific files
│   ├── barrier.conf           # Server configuration
│   ├── setup.sh              # Server setup script
│   └── *.service             # Systemd service files
├── logs/                      # Shared log directory
└── .flox/                     # Flox environment
```

## Quick Start

### Server Setup (on the host machine)
```bash
# 1. Setup server
./server/setup.sh

# 2. Configure firewall  
./server/configure-firewall.sh

# 3. Install as service (optional)
./server/install-service.sh

# 4. Start server
barriers -f --no-tray --debug INFO --name $(hostname) --config ~/.barrier/barrier.conf
```

### Client Setup (on remote machines)
```bash
# 1. Activate environment
flox activate

# 2. Setup client
./client/scripts/setup-client.sh

# 3. Start client
./client/scripts/start-client.sh
```

## Configuration

- **Server IP**: 192.168.1.206 (from server/barrier.conf)
- **Client Name**: "client" 
- **Port**: 24800/tcp
- **Layout**: server ← → client

## Anti-Hanging Features

### Client-Side
- SSL debugging with `--disable-crypto` option
- Connection monitoring and auto-restart
- Comprehensive network diagnostics
- Process monitoring and cleanup

### Server-Side  
- Systemd service with auto-restart
- Firewall configuration helpers
- Service management scripts

## Troubleshooting

- **Client issues**: See `client/docs/troubleshooting.md`
- **Connection debugging**: `./client/scripts/debug-barrier.sh [server-ip]`
- **Service management**: `systemctl --user status barrier-server`

## Dependencies

- barrier (installed via apt)
- flox environment with debugging tools
- X11/Wayland display server
- Network connectivity between machines