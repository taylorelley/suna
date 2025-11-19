# Suna Quick Start Guide

## First Time Setup

1. **Run the setup wizard:**
   ```bash
   python3 setup.py
   ```

2. **Choose "Manual" setup method** (recommended for local development)

3. **Follow the prompts** to configure:
   - Supabase (local or cloud)
   - Daytona
   - LLM API keys (Anthropic, OpenAI, etc.)
   - Optional integrations

## Running Suna

### Option 1: Systemd Service (Recommended) 🚀

**One-time setup:**
```bash
mkdir -p ~/.config/systemd/user
cp suna.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

**Daily usage:**
```bash
# Start all services
systemctl --user start suna.service

# Stop all services
systemctl --user stop suna.service

# Check status
systemctl --user status suna.service

# View logs
journalctl --user -u suna.service -f
```

**Enable auto-start on boot:**
```bash
systemctl --user enable suna.service
```

📖 **Full documentation:** [SYSTEMD_SETUP.md](SYSTEMD_SETUP.md)

---

### Option 2: Manager Script

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

**Logs are in:** `logs/` directory

---

### Option 3: Manual (Multiple Terminals)

**Terminal 1 - Local Supabase** (if using local setup):
```bash
cd backend
npx supabase start
```

**Terminal 2 - Redis:**
```bash
docker compose up redis -d
```

**Terminal 3 - Frontend:**
```bash
cd frontend
npm run dev
```

**Terminal 4 - Backend:**
```bash
cd backend
uv run api.py
```

**Terminal 5 - Background Worker:**
```bash
cd backend
uv run dramatiq run_agent_background
```

---

## Accessing Suna

Once running:
- **Frontend:** http://localhost:3000
- **Backend API:** http://localhost:8000

## Troubleshooting

### Check what's running:
```bash
./suna-manager.sh status
# or
systemctl --user status suna.service
```

### View logs:
```bash
# Systemd logs
journalctl --user -u suna.service -f

# Individual component logs
tail -f logs/backend.log
tail -f logs/frontend.log
tail -f logs/worker.log
```

### Port conflicts:
```bash
# Find what's using a port
sudo lsof -i :3000
sudo lsof -i :8000
```

### Reset everything:
```bash
# Stop all services
./suna-manager.sh stop
# or
systemctl --user stop suna.service

# Clean up
docker compose down
cd backend && npx supabase stop
```

## Key Files

- `setup.py` - Initial setup wizard
- `suna-manager.sh` - Service management script
- `suna.service` - Systemd service file
- `SYSTEMD_SETUP.md` - Detailed systemd documentation
- `backend/.env` - Backend configuration
- `frontend/.env.local` - Frontend configuration
- `logs/` - Service logs

## Next Steps

1. **Create a user account** at http://localhost:3000
2. **Create your first agent**
3. **Explore the documentation** at https://github.com/kortix-ai/suna

## Getting Help

- **Issues:** https://github.com/kortix-ai/suna/issues
- **Discussions:** https://github.com/kortix-ai/suna/discussions
- **Documentation:** https://github.com/kortix-ai/suna

---

**Pro Tip:** Use the systemd service for the best experience - no more juggling terminals! 🎯
