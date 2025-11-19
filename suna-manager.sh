#!/bin/bash
# ============================================================================
# Suna Service Manager Script
# ============================================================================
# This script manages all Suna services (Supabase, Redis, Frontend, Backend, Worker)
# Usage: ./suna-manager.sh {start|stop|restart|status}
# ============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# PID files to track running processes
PID_DIR="$SCRIPT_DIR/.suna_pids"
BACKEND_PID="$PID_DIR/backend.pid"
WORKER_PID="$PID_DIR/worker.pid"
FRONTEND_PID="$PID_DIR/frontend.pid"

# Log directory
LOG_DIR="$SCRIPT_DIR/logs"
BACKEND_LOG="$LOG_DIR/backend.log"
WORKER_LOG="$LOG_DIR/worker.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"
SUPABASE_LOG="$LOG_DIR/supabase.log"

# Configurable startup delays (can be overridden via environment variables)
BACKEND_STARTUP_DELAY=${BACKEND_STARTUP_DELAY:-3}
WORKER_STARTUP_DELAY=${WORKER_STARTUP_DELAY:-3}
FRONTEND_STARTUP_DELAY=${FRONTEND_STARTUP_DELAY:-5}

# Detect if local Supabase is configured
function is_local_supabase() {
    if [ -f "$BACKEND_DIR/.env" ]; then
        local supabase_url
        supabase_url=$(grep "^SUPABASE_URL=" "$BACKEND_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [[ "$supabase_url" == *"127.0.0.1"* ]] || [[ "$supabase_url" == *"localhost"* ]]; then
            return 0
        fi
    fi
    return 1
}

# Print colored message
function print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

function print_success() {
    echo -e "${GREEN}✅  $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function print_error() {
    echo -e "${RED}❌  $1${NC}"
}

# Create necessary directories
function setup_directories() {
    mkdir -p "$PID_DIR"
    mkdir -p "$LOG_DIR"
}

# Check if a process is running
function is_running() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    return 1
}

# Start Local Supabase
function start_supabase() {
    if is_local_supabase; then
        print_info "Starting Local Supabase..."
        cd "$BACKEND_DIR"

        # Check if Supabase is already running
        if npx supabase status > /dev/null 2>&1; then
            print_success "Local Supabase is already running"
            cd "$SCRIPT_DIR"
            return 0
        fi

        # Verify Supabase project is initialized
        if [ ! -f "supabase/config.toml" ]; then
            print_error "Supabase project not initialized. Run 'npx supabase init' in backend directory first."
            cd "$SCRIPT_DIR"
            return 1
        fi

        # Start Supabase in foreground so user can see progress and respond to prompts
        print_info "This may take a few minutes on first run (downloading Docker images)..."
        if npx supabase start; then
            print_success "Local Supabase started successfully"
            cd "$SCRIPT_DIR"
            return 0
        else
            print_error "Failed to start Local Supabase"
            cd "$SCRIPT_DIR"
            return 1
        fi
    else
        print_info "Using Cloud Supabase (no local instance to start)"
    fi
}

# Stop Local Supabase
function stop_supabase() {
    if is_local_supabase; then
        print_info "Stopping Local Supabase..."
        cd "$BACKEND_DIR"
        npx supabase stop >> "$SUPABASE_LOG" 2>&1 || true
        print_success "Local Supabase stopped"
        cd "$SCRIPT_DIR"
    fi
}

# Start Redis
function start_redis() {
    print_info "Starting Redis..."

    # Check if Redis is already running
    if docker ps | grep -q "suna.*redis" || docker compose ps redis 2>/dev/null | grep -q "running"; then
        print_success "Redis is already running"
    else
        docker compose up redis -d
        sleep 2
        print_success "Redis started"
    fi
}

# Stop Redis
function stop_redis() {
    print_info "Stopping Redis..."
    docker compose down redis 2>/dev/null || true
    print_success "Redis stopped"
}

# Start Backend API
function start_backend() {
    if is_running "$BACKEND_PID"; then
        print_success "Backend is already running (PID: $(cat $BACKEND_PID))"
        return 0
    fi

    print_info "Starting Backend API..."
    cd "$BACKEND_DIR"

    # Start backend in background and save PID
    nohup uv run api.py >> "$BACKEND_LOG" 2>&1 &
    echo $! > "$BACKEND_PID"

    sleep "$BACKEND_STARTUP_DELAY"
    if is_running "$BACKEND_PID"; then
        print_success "Backend API started (PID: $(cat $BACKEND_PID))"
    else
        print_error "Failed to start Backend API"
        return 1
    fi
    cd "$SCRIPT_DIR"
}

# Stop Backend API
function stop_backend() {
    if is_running "$BACKEND_PID"; then
        print_info "Stopping Backend API..."
        local pid
        pid=$(cat "$BACKEND_PID")
        kill "$pid" 2>/dev/null || true
        sleep 2

        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
        fi

        rm -f "$BACKEND_PID"
        print_success "Backend API stopped"
    else
        print_info "Backend API is not running"
    fi
}

# Start Background Worker
function start_worker() {
    if is_running "$WORKER_PID"; then
        print_success "Background Worker is already running (PID: $(cat $WORKER_PID))"
        return 0
    fi

    print_info "Starting Background Worker..."
    cd "$BACKEND_DIR"

    # Start worker in background and save PID
    nohup uv run dramatiq run_agent_background >> "$WORKER_LOG" 2>&1 &
    echo $! > "$WORKER_PID"

    sleep "$WORKER_STARTUP_DELAY"
    if is_running "$WORKER_PID"; then
        print_success "Background Worker started (PID: $(cat $WORKER_PID))"
    else
        print_error "Failed to start Background Worker"
        return 1
    fi
    cd "$SCRIPT_DIR"
}

# Stop Background Worker
function stop_worker() {
    if is_running "$WORKER_PID"; then
        print_info "Stopping Background Worker..."
        local pid
        pid=$(cat "$WORKER_PID")
        kill "$pid" 2>/dev/null || true
        sleep 2

        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
        fi

        rm -f "$WORKER_PID"
        print_success "Background Worker stopped"
    else
        print_info "Background Worker is not running"
    fi
}

# Start Frontend
function start_frontend() {
    if is_running "$FRONTEND_PID"; then
        print_success "Frontend is already running (PID: $(cat $FRONTEND_PID))"
        return 0
    fi

    print_info "Starting Frontend..."
    cd "$FRONTEND_DIR"

    # Start frontend in background and save PID
    nohup npm run dev >> "$FRONTEND_LOG" 2>&1 &
    echo $! > "$FRONTEND_PID"

    sleep "$FRONTEND_STARTUP_DELAY"
    if is_running "$FRONTEND_PID"; then
        print_success "Frontend started (PID: $(cat $FRONTEND_PID))"
    else
        print_error "Failed to start Frontend"
        return 1
    fi
    cd "$SCRIPT_DIR"
}

# Stop Frontend
function stop_frontend() {
    if is_running "$FRONTEND_PID"; then
        print_info "Stopping Frontend..."
        local pid
        pid=$(cat "$FRONTEND_PID")

        # Kill the process group to stop npm and all child processes
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
        sleep 2

        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
        fi

        rm -f "$FRONTEND_PID"
        print_success "Frontend stopped"
    else
        print_info "Frontend is not running"
    fi
}

# Start all services
function start_all() {
    echo ""
    print_info "========================================="
    print_info "Starting Suna Services"
    print_info "========================================="
    echo ""

    setup_directories

    # Start services in order
    start_supabase || return 1
    start_redis || return 1
    start_backend || return 1
    start_worker || return 1
    start_frontend || return 1

    echo ""
    print_success "========================================="
    print_success "All Suna services started successfully!"
    print_success "========================================="
    echo ""
    print_info "Access Suna at: http://localhost:3000"
    print_info "Backend API at: http://localhost:8000"
    echo ""
    print_info "Logs are available in: $LOG_DIR"
    echo ""
}

# Stop all services
function stop_all() {
    echo ""
    print_info "========================================="
    print_info "Stopping Suna Services"
    print_info "========================================="
    echo ""

    # Stop services in reverse order
    stop_frontend
    stop_worker
    stop_backend
    stop_redis
    stop_supabase

    echo ""
    print_success "========================================="
    print_success "All Suna services stopped"
    print_success "========================================="
    echo ""
}

# Show status of all services
function show_status() {
    echo ""
    print_info "========================================="
    print_info "Suna Services Status"
    print_info "========================================="
    echo ""

    # Supabase status
    if is_local_supabase; then
        echo -n "Local Supabase: "
        if cd "$BACKEND_DIR" && npx supabase status > /dev/null 2>&1; then
            print_success "Running"
        else
            print_error "Stopped"
        fi
        cd "$SCRIPT_DIR"
    else
        echo -n "Supabase: "
        print_info "Cloud (managed externally)"
    fi

    # Redis status
    echo -n "Redis: "
    if docker ps | grep -q "suna.*redis" || docker compose ps redis 2>/dev/null | grep -q "running"; then
        print_success "Running"
    else
        print_error "Stopped"
    fi

    # Backend status
    echo -n "Backend API: "
    if is_running "$BACKEND_PID"; then
        print_success "Running (PID: $(cat $BACKEND_PID))"
    else
        print_error "Stopped"
    fi

    # Worker status
    echo -n "Background Worker: "
    if is_running "$WORKER_PID"; then
        print_success "Running (PID: $(cat $WORKER_PID))"
    else
        print_error "Stopped"
    fi

    # Frontend status
    echo -n "Frontend: "
    if is_running "$FRONTEND_PID"; then
        print_success "Running (PID: $(cat $FRONTEND_PID))"
    else
        print_error "Stopped"
    fi

    echo ""
}

# Main script logic
case "$1" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
