# Suna Systemd Service Setup Guide

This guide explains how to run Suna as a systemd service, eliminating the need to manage multiple terminal windows.

## Overview

Instead of manually starting 5 separate services in different terminals, you can use systemd to manage everything as a single service:

- **Before**: 5 terminal windows (Supabase, Redis, Frontend, Backend, Worker)
- **After**: Single `systemctl` command

## Prerequisites

1. Complete the initial Suna setup using `python3 setup.py`
2. Ensure all dependencies are installed
3. Linux system with systemd (included in most modern Linux distributions)

## Quick Start

### 1. Install the systemd service

```bash
# Copy the service file to systemd user directory
mkdir -p ~/.config/systemd/user
cp suna.service ~/.config/systemd/user/

# Reload systemd to recognize the new service
systemctl --user daemon-reload

# Enable the service to start on boot (optional)
systemctl --user enable suna.service
```

### 2. Start Suna

```bash
# Start all Suna services
systemctl --user start suna.service

# Check status
systemctl --user status suna.service
```

### 3. Access Suna

Once started, access Suna at:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000

## Service Management Commands

### Start Services
```bash
systemctl --user start suna.service
```

### Stop Services
```bash
systemctl --user stop suna.service
```

### Restart Services
```bash
systemctl --user restart suna.service
```

### Check Status
```bash
systemctl --user status suna.service
```

### View Logs
```bash
# View systemd logs
journalctl --user -u suna.service -f

# View component-specific logs
tail -f ~/suna/logs/backend.log
tail -f ~/suna/logs/frontend.log
tail -f ~/suna/logs/worker.log
tail -f ~/suna/logs/supabase.log
```

### Enable/Disable Auto-start on Boot
```bash
# Enable auto-start
systemctl --user enable suna.service

# Disable auto-start
systemctl --user disable suna.service

# Check if enabled
systemctl --user is-enabled suna.service
```

## Manual Control (Without Systemd)

If you prefer not to use systemd, you can use the manager script directly:

```bash
# Start all services
./suna-manager.sh start

# Stop all services
./suna-manager.sh stop

# Restart all services
./suna-manager.sh restart

# Check status
./suna-manager.sh status
```

## Log Files

Service logs are stored in the `logs/` directory:

```bash
~/suna/logs/
├── backend.log      # Backend API logs
├── frontend.log     # Frontend logs
├── worker.log       # Background worker logs
└── supabase.log     # Local Supabase logs (if using local setup)
```

## Troubleshooting

### Service won't start
1. Check the service status: `systemctl --user status suna.service`
2. View detailed logs: `journalctl --user -u suna.service -n 50`
3. Check individual component logs in `~/suna/logs/`
4. Ensure Docker is running: `docker ps`

### Permission errors
```bash
# Make sure the manager script is executable
chmod +x ~/suna/suna-manager.sh
```

### Port conflicts
If ports 3000 or 8000 are already in use:
```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :8000

# Stop the conflicting service or update Suna's port configuration
```

### Services not stopping cleanly
```bash
# Force stop all Suna services
./suna-manager.sh stop

# Or manually kill processes
pkill -f "uv run api.py"
pkill -f "uv run dramatiq"
pkill -f "npm run dev"
```

### Local Supabase issues
```bash
# Check Supabase status
cd backend && npx supabase status

# Restart Supabase
cd backend && npx supabase stop
cd backend && npx supabase start
```

## Advanced Configuration

### Custom Installation Path

If Suna is installed in a different location, update the systemd service file:

```bash
# Edit the service file
nano ~/.config/systemd/user/suna.service

# Update these lines:
WorkingDirectory=/your/custom/path/suna
ExecStart=/your/custom/path/suna/suna-manager.sh start
ExecStop=/your/custom/path/suna/suna-manager.sh stop

# Reload systemd
systemctl --user daemon-reload
```

### Environment Variables

The service uses the `.env` files created during setup:
- `backend/.env` - Backend configuration
- `frontend/.env.local` - Frontend configuration

To modify configuration:
1. Edit the appropriate `.env` file
2. Restart the service: `systemctl --user restart suna.service`

### Startup Delays

On slower systems, you may need to increase the startup delays to ensure services have enough time to initialize. Set these environment variables before starting the service:

```bash
# Set custom startup delays (in seconds)
export BACKEND_STARTUP_DELAY=5     # Default: 3
export WORKER_STARTUP_DELAY=5      # Default: 3
export FRONTEND_STARTUP_DELAY=10   # Default: 5

# Then start the service
systemctl --user start suna.service
```

Or set them in the systemd service file for persistence:

```bash
nano ~/.config/systemd/user/suna.service
```

Add under `[Service]`:
```ini
Environment="BACKEND_STARTUP_DELAY=5"
Environment="WORKER_STARTUP_DELAY=5"
Environment="FRONTEND_STARTUP_DELAY=10"
```

Then reload: `systemctl --user daemon-reload`

### Resource Limits

To limit resource usage, edit `~/.config/systemd/user/suna.service`:

```ini
[Service]
# Limit memory to 4GB
MemoryLimit=4G

# Limit CPU usage to 50%
CPUQuota=50%
```

Then reload: `systemctl --user daemon-reload`

## Uninstalling the Service

```bash
# Stop and disable the service
systemctl --user stop suna.service
systemctl --user disable suna.service

# Remove the service file
rm ~/.config/systemd/user/suna.service

# Reload systemd
systemctl --user daemon-reload
```

## Benefits of Systemd Service

1. **Single Command**: Start/stop all services with one command
2. **Auto-restart**: Services automatically restart on failure
3. **Boot Integration**: Optionally start Suna on system boot
4. **Centralized Logs**: View all logs through journalctl
5. **Resource Management**: Limit CPU/memory usage
6. **Status Monitoring**: Easy status checking with systemctl

## Comparison: Before vs After

### Before (Manual Setup)

Terminal 1:
```bash
cd backend && npx supabase start
```

Terminal 2:
```bash
docker compose up redis -d
```

Terminal 3:
```bash
cd frontend && npm run dev
```

Terminal 4:
```bash
cd backend && uv run api.py
```

Terminal 5:
```bash
cd backend && uv run dramatiq run_agent_background
```

### After (Systemd Service)

Single command:
```bash
systemctl --user start suna.service
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/kortix-ai/suna/issues
- Documentation: https://github.com/kortix-ai/suna

---

**Note**: This systemd service is designed for local development setups. For production deployments, consider using Docker Compose or container orchestration platforms like Kubernetes.
