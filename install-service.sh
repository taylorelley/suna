#!/bin/bash
# ============================================================================
# Suna Service Installer
# ============================================================================
# Automatically detects whether to install as user or system service
# ============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check if systemd is available
if ! command -v systemctl >/dev/null 2>&1; then
    print_error "systemd is not installed on this system"
    print_info "Please use the manager script directly:"
    echo -e "  ${GREEN}./suna-manager.sh start${NC}"
    exit 1
fi

# Check if systemd is running
if ! systemctl is-system-running >/dev/null 2>&1 && ! systemctl --user status >/dev/null 2>&1; then
    print_warning "systemd is not running or not available"
    print_warning "This is common in:"
    print_warning "  • Container environments (Docker, LXC)"
    print_warning "  • Systems using other init systems (SysV, OpenRC)"
    echo ""
    print_info "You can still use the manager script directly:"
    echo -e "  ${GREEN}./suna-manager.sh start${NC}"
    echo -e "  ${GREEN}./suna-manager.sh stop${NC}"
    echo -e "  ${GREEN}./suna-manager.sh restart${NC}"
    echo -e "  ${GREEN}./suna-manager.sh status${NC}"
    exit 0
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - installing as system service"

    # Check if systemd is actually running
    if ! systemctl is-system-running >/dev/null 2>&1; then
        print_error "systemd is not running as PID 1"
        print_info "Use the manager script directly instead:"
        echo -e "  ${GREEN}./suna-manager.sh start${NC}"
        exit 1
    fi

    # Update the system service file with correct paths
    SERVICE_FILE="$SCRIPT_DIR/suna-system.service"
    INSTALL_PATH="/etc/systemd/system/suna.service"

    # Update WorkingDirectory and ExecStart paths in the service file
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$SCRIPT_DIR|g" "$SERVICE_FILE"
    sed -i "s|ExecStart=.*|ExecStart=$SCRIPT_DIR/suna-manager.sh start|g" "$SERVICE_FILE"
    sed -i "s|ExecStop=.*|ExecStop=$SCRIPT_DIR/suna-manager.sh stop|g" "$SERVICE_FILE"
    sed -i "s|ExecReload=.*|ExecReload=$SCRIPT_DIR/suna-manager.sh restart|g" "$SERVICE_FILE"

    print_info "Copying service file to $INSTALL_PATH..."
    cp "$SERVICE_FILE" "$INSTALL_PATH"

    print_info "Reloading systemd daemon..."
    systemctl daemon-reload

    print_success "System service installed successfully!"
    echo ""
    print_info "Available commands:"
    echo "  systemctl start suna.service     - Start all services"
    echo "  systemctl stop suna.service      - Stop all services"
    echo "  systemctl status suna.service    - Check status"
    echo "  systemctl enable suna.service    - Enable auto-start on boot"
    echo "  journalctl -u suna.service -f    - View logs"
    echo ""
    print_info "To start Suna now, run:"
    echo -e "  ${GREEN}systemctl start suna.service${NC}"

else
    print_info "Running as non-root user - installing as user service"

    # Check if user session bus is available
    if ! systemctl --user status >/dev/null 2>&1; then
        print_error "User systemd session not available"
        print_warning "This can happen in:"
        print_warning "  • SSH sessions without lingering enabled"
        print_warning "  • Container environments"
        print_warning "  • Systems without systemd user sessions"
        echo ""
        print_info "Workaround options:"
        print_info "1. Enable lingering for your user:"
        echo "     sudo loginctl enable-linger $USER"
        echo ""
        print_info "2. Use the manager script directly:"
        echo "     ./suna-manager.sh start"
        exit 1
    fi

    SERVICE_FILE="$SCRIPT_DIR/suna.service"
    USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
    INSTALL_PATH="$USER_SYSTEMD_DIR/suna.service"

    print_info "Creating user systemd directory..."
    mkdir -p "$USER_SYSTEMD_DIR"

    print_info "Copying service file to $INSTALL_PATH..."
    cp "$SERVICE_FILE" "$INSTALL_PATH"

    # Update paths in the service file to use absolute paths
    sed -i "s|WorkingDirectory=%h/suna|WorkingDirectory=$SCRIPT_DIR|g" "$INSTALL_PATH"
    sed -i "s|ExecStart=%h/suna/suna-manager.sh|ExecStart=$SCRIPT_DIR/suna-manager.sh|g" "$INSTALL_PATH"
    sed -i "s|ExecStop=%h/suna/suna-manager.sh|ExecStop=$SCRIPT_DIR/suna-manager.sh|g" "$INSTALL_PATH"
    sed -i "s|ExecReload=%h/suna/suna-manager.sh|ExecReload=$SCRIPT_DIR/suna-manager.sh|g" "$INSTALL_PATH"

    print_info "Reloading systemd user daemon..."
    systemctl --user daemon-reload

    print_success "User service installed successfully!"
    echo ""
    print_info "Available commands:"
    echo "  systemctl --user start suna.service     - Start all services"
    echo "  systemctl --user stop suna.service      - Stop all services"
    echo "  systemctl --user status suna.service    - Check status"
    echo "  systemctl --user enable suna.service    - Enable auto-start on login"
    echo "  journalctl --user -u suna.service -f    - View logs"
    echo ""
    print_info "To start Suna now, run:"
    echo -e "  ${GREEN}systemctl --user start suna.service${NC}"
fi

echo ""
print_info "You can also use the manager script directly:"
echo "  ./suna-manager.sh start|stop|restart|status"
