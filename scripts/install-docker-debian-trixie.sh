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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user."
        log_info "The script will use sudo when needed."
        exit 1
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

# Update package index
update_package_index() {
    log_info "Updating package index..."
    sudo apt-get update
}

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

# Add Docker's official GPG key
add_docker_gpg_key() {
    log_info "Adding Docker's official GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
}

# Add Docker repository
add_docker_repository() {
    log_info "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# Update package index with Docker repo
update_with_docker_repo() {
    log_info "Updating package index with Docker repository..."
    sudo apt-get update
}

# Install Docker Client only
install_docker_client() {
    log_info "Installing Docker CLI client and plugins only..."
    sudo apt-get install -y \
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
}

# Main function
main() {
    log_info "Starting Docker client installation for Debian Trixie..."
    
    check_root
    check_debian_trixie
    check_existing_docker
    
    update_package_index
    install_prerequisites
    add_docker_gpg_key
    add_docker_repository
    update_with_docker_repo
    install_docker_client
    configure_docker_client
    verify_installation
    print_post_install_info
    
    log_info "Docker client installation script completed successfully!"
}

# Run main function
main "$@"