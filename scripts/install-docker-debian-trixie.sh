#!/bin/bash

# Script to install Docker client only on Debian Trixie
# This script installs only the Docker CLI client to connect to remote Docker daemons
# Use DOCKER_HOST environment variable to specify the remote Docker daemon

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check sudo privileges and set sudo command
SUDO_CMD=""
NEED_ROOT_PASSWORD=false
ROOT_SHELL_PID=""

check_sudo_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user."
        log_info "The script will use sudo when needed or prompt for root access."
        exit 1
    fi

    # Check if user has sudo privileges
    if sudo -n true 2>/dev/null; then
        log_info "User has sudo privileges (passwordless). Using sudo for privileged operations."
        SUDO_CMD="sudo"
    elif groups "$USER" | grep -q '\bsudo\b\|wheel\b'; then
        log_info "User is in sudo/wheel group. Will prompt for sudo password when needed."
        SUDO_CMD="sudo"
    else
        log_warn "User does not appear to have sudo privileges."
        log_warn "Checking if root password access is available..."
        
        # For non-interactive environments (like make), check USER_INTERACTIVE variable
        if [[ ! -t 0 ]] || [[ -n "${MAKE_RESTARTS:-}" ]] || [[ -n "${MAKELEVEL:-}" ]]; then
            if [[ "${USER_INTERACTIVE:-0}" != "1" ]]; then
                log_error "Script is running in non-interactive mode (possibly from make)."
                log_error "Root password prompts may not work properly."
                log_error "To enable interactive mode from make, set USER_INTERACTIVE=1:"
                log_error "  make install-docker USER_INTERACTIVE=1"
                log_error "Or run this script directly:"
                log_error "  ./scripts/install-docker-debian-trixie.sh"
                log_error "Or ensure user has sudo privileges:"
                log_error "  sudo usermod -aG sudo $USER"
                exit 1
            else
                log_info "USER_INTERACTIVE=1 detected. Enabling interactive root prompts from make."
            fi
        fi
        
        log_warn "Will attempt to use 'su -c' for root operations."
        log_info "You will be prompted for the root password once, then commands will be batched."
        SUDO_CMD="su -c"
        NEED_ROOT_PASSWORD=true
    fi
}

# Check if running on Debian Trixie
check_debian_trixie() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi

    source /etc/os-release
    
    if [[ "$ID" != "debian" ]]; then
        log_error "This script is designed for Debian only. Detected OS: $ID"
        exit 1
    fi

    # Check for Trixie (Debian 13)
    if [[ "$VERSION_CODENAME" != "trixie" ]] && [[ "$VERSION_ID" != "13" ]]; then
        log_warn "This script is optimized for Debian Trixie. Detected: $VERSION_CODENAME ($VERSION_ID)"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_info "Debian Trixie detected. Proceeding with installation..."
}

# Check if Docker is already installed
check_existing_docker() {
    if command -v docker &> /dev/null; then
        log_warn "Docker is already installed:"
        docker --version
        read -p "Do you want to reinstall Docker? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Exiting without changes."
            exit 0
        fi
    fi
}

# Create a batch script for root operations
create_root_batch_script() {
    if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
        local batch_script="/tmp/docker_install_batch_$$"
        cat > "$batch_script" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "[ROOT] Starting Docker installation batch operations..."

# Update package index
echo "[ROOT] Updating package index..."
apt-get update

# Install prerequisites
echo "[ROOT] Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release

# Create keyrings directory
echo "[ROOT] Creating keyrings directory..."
install -m 0755 -d /etc/apt/keyrings

# Add Docker GPG key
echo "[ROOT] Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "[ROOT] Adding Docker repository..."
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" > /etc/apt/sources.list.d/docker.list

# Update package index with Docker repo
echo "[ROOT] Updating package index with Docker repository..."  
apt-get update

# Install Docker client
echo "[ROOT] Installing Docker CLI client and plugins..."
apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin

echo "[ROOT] Docker installation batch operations completed successfully!"
EOF
        chmod +x "$batch_script"
        echo "$batch_script"
    fi
}

# Execute root batch script
execute_root_batch() {
    if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
        local batch_script=$(create_root_batch_script)
        
        log_info "Executing all root operations in a single session..."
        log_warn "Please enter root password:"
        
        if [[ "${USER_INTERACTIVE:-0}" == "1" ]] && ([[ ! -t 0 ]] || [[ -n "${MAKELEVEL:-}" ]]); then
            exec < /dev/tty
            if su -c "$batch_script"; then
                # Cleanup on success
                rm -f "$batch_script"
                return 0
            else
                log_error "Root authentication failed. Cannot proceed with installation."
                rm -f "$batch_script"
                exit 1
            fi
        else
            if su -c "$batch_script" </dev/tty; then
                # Cleanup on success
                rm -f "$batch_script"
                return 0
            else
                log_error "Root authentication failed. Cannot proceed with installation."
                rm -f "$batch_script"
                exit 1
            fi
        fi
    fi
    return 1
}

# Execute command with appropriate privileges (fallback for individual commands)
run_as_root() {
    if [[ "$SUDO_CMD" == "su -c" ]]; then
        if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
            echo "Root privileges required for: $*"
            echo "Please enter root password:"
        fi
        # Force password prompt to be visible by using /dev/tty
        if [[ "${USER_INTERACTIVE:-0}" == "1" ]] && ([[ ! -t 0 ]] || [[ -n "${MAKELEVEL:-}" ]]); then
            # When USER_INTERACTIVE=1 and running from make, ensure tty interaction
            exec < /dev/tty
            su -c "$*"
        else
            su -c "$*" </dev/tty
        fi
    else
        $SUDO_CMD "$@"
    fi
}

# Update package index
update_package_index() {
    log_info "Updating package index..."
    run_as_root apt-get update
}

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    run_as_root apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

# Add Docker's official GPG key
add_docker_gpg_key() {
    log_info "Adding Docker's official GPG key..."
    run_as_root install -m 0755 -d /etc/apt/keyrings
    
    if [[ "$SUDO_CMD" == "su -c" ]]; then
        if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
            echo "Root privileges required for: adding Docker GPG key"
            echo "Please enter root password:"
        fi
        if [[ "${USER_INTERACTIVE:-0}" == "1" ]] && ([[ ! -t 0 ]] || [[ -n "${MAKELEVEL:-}" ]]); then
            exec < /dev/tty
            curl -fsSL https://download.docker.com/linux/debian/gpg | su -c "gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
        else
            curl -fsSL https://download.docker.com/linux/debian/gpg | su -c "gpg --dearmor -o /etc/apt/keyrings/docker.gpg" </dev/tty
        fi
        run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
    else
        curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO_CMD gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
    fi
}

# Add Docker repository
add_docker_repository() {
    log_info "Adding Docker repository..."
    local repo_line="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable"
    
    if [[ "$SUDO_CMD" == "su -c" ]]; then
        if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
            echo "Root privileges required for: adding Docker repository"
            echo "Please enter root password:"
        fi
        if [[ "${USER_INTERACTIVE:-0}" == "1" ]] && ([[ ! -t 0 ]] || [[ -n "${MAKELEVEL:-}" ]]); then
            exec < /dev/tty
            echo "$repo_line" | su -c "tee /etc/apt/sources.list.d/docker.list > /dev/null"
        else
            echo "$repo_line" | su -c "tee /etc/apt/sources.list.d/docker.list > /dev/null" </dev/tty
        fi
    else
        echo "$repo_line" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
}

# Update package index with Docker repo
update_with_docker_repo() {
    log_info "Updating package index with Docker repository..."
    run_as_root apt-get update
}

# Install Docker Client only
install_docker_client() {
    log_info "Installing Docker CLI client and plugins only..."
    run_as_root apt-get install -y \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin
}

# Configure Docker client environment
configure_docker_client() {
    log_info "Docker client configuration..."
    log_info "Docker client installed successfully!"
    log_warn "Remember to set the DOCKER_HOST environment variable before using Docker commands."
    log_info "Examples:"
    echo "  export DOCKER_HOST=tcp://remote-docker-host:2376    # For remote TCP connection"
    echo "  export DOCKER_HOST=unix:///var/run/docker.sock      # For local socket (if daemon exists)"
    echo "  export DOCKER_HOST=ssh://user@remote-host           # For SSH connection"
}



# Verify installation
verify_installation() {
    log_info "Verifying Docker client installation..."
    
    # Check Docker version
    if docker --version; then
        log_info "Docker client installed successfully!"
    else
        log_error "Docker client installation verification failed."
        return 1
    fi

    log_warn "Note: Docker daemon is not installed. You need to set DOCKER_HOST to connect to a remote daemon."
}

# Print post-installation information
print_post_install_info() {
    log_info "Docker client installation completed!"
    echo
    log_info "Usage:"
    echo "1. Set DOCKER_HOST environment variable before running Docker commands:"
    echo "   export DOCKER_HOST=tcp://your-docker-host:2376"
    echo "   export DOCKER_HOST=ssh://user@your-docker-host"
    echo
    echo "2. Test Docker client connection:"
    echo "   docker version"
    echo "   docker info"
    echo
    echo "3. Run Docker commands as usual:"
    echo "   docker ps"
    echo "   docker run hello-world"
    echo
    log_info "Available Docker tools:"
    echo "  - Docker CLI: docker"
    echo "  - Docker Compose: docker compose"
    echo "  - Docker Buildx: docker buildx"
    echo
    log_warn "Remember: No local Docker daemon is installed. Set DOCKER_HOST for each session."
    
    # If user needed root password, suggest sudo setup for future
    if [[ "$NEED_ROOT_PASSWORD" == true ]]; then
        echo
        log_info "Tip: To avoid root password prompts in the future:"
        echo "  sudo usermod -aG sudo $USER"
        echo "  # Then log out and log back in"
    fi
}

# Main function
main() {
    log_info "Starting Docker client installation for Debian Trixie..."
    
    check_sudo_privileges
    check_debian_trixie
    check_existing_docker
    
    # Try to execute all root operations in a single batch to minimize password prompts
    if execute_root_batch; then
        log_info "All root operations completed in batch mode."
    else
        # Fallback to individual commands for sudo users
        log_info "Executing individual installation steps..."
        update_package_index
        install_prerequisites
        add_docker_gpg_key
        add_docker_repository
        update_with_docker_repo
        install_docker_client
    fi
    
    configure_docker_client
    verify_installation
    print_post_install_info
    
    log_info "Docker client installation script completed successfully!"
}

# Run main function
main "$@"