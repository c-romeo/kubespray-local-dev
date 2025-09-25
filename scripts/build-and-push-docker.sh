#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if bws is installed
if ! command -v bws &> /dev/null; then
    print_error "Bitwarden Secrets CLI (bws) is not installed or not in PATH"
    print_error "Please install bws from: https://bitwarden.com/help/secrets-manager-cli/"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBESPRAY_FORK_DIR="$PROJECT_ROOT/kubespray-fork"

print_status "Project root: $PROJECT_ROOT"
print_status "Kubespray fork directory: $KUBESPRAY_FORK_DIR"

# Check if kubespray-fork directory exists
if [ ! -d "$KUBESPRAY_FORK_DIR" ]; then
    print_error "kubespray-fork directory not found at: $KUBESPRAY_FORK_DIR"
    print_error "Please run 'make clone-kubespray' first"
    exit 1
fi

# Change to kubespray-fork directory
print_status "Changing to kubespray-fork directory..."
cd "$KUBESPRAY_FORK_DIR"

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found in kubespray-fork directory"
    exit 1
fi

# Get Docker registry and credentials from Bitwarden Secrets
print_status "Retrieving Docker registry credentials from Bitwarden Secrets..."

# Get registry URL
DOCKER_REGISTRY=$(bws secret get DOCKER_REGISTRY | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
if [ -z "$DOCKER_REGISTRY" ]; then
    print_error "Failed to retrieve DOCKER_REGISTRY from Bitwarden Secrets"
    exit 1
fi
print_success "Retrieved Docker registry: $DOCKER_REGISTRY"

# Get registry username
DOCKER_USERNAME=$(bws secret get DOCKER_USERNAME | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
if [ -z "$DOCKER_USERNAME" ]; then
    print_error "Failed to retrieve DOCKER_USERNAME from Bitwarden Secrets"
    exit 1
fi
print_success "Retrieved Docker username: $DOCKER_USERNAME"

# Get registry password
DOCKER_PASSWORD=$(bws secret get DOCKER_PASSWORD | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
if [ -z "$DOCKER_PASSWORD" ]; then
    print_error "Failed to retrieve DOCKER_PASSWORD from Bitwarden Secrets"
    exit 1
fi
print_success "Retrieved Docker password: [HIDDEN]"

# Generate image name and tags
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
IMAGE_NAME="kubespray"
BASE_TAG="${DOCKER_REGISTRY}/${IMAGE_NAME}"
VERSIONED_TAG="${BASE_TAG}:${TIMESTAMP}-${GIT_COMMIT}"
LATEST_TAG="${BASE_TAG}:latest"

print_status "Building Docker image..."
print_status "Image will be tagged as:"
print_status "  - $VERSIONED_TAG"
print_status "  - $LATEST_TAG"

# Build the Docker image
print_status "Building Docker image with versioned tag..."
if docker build -t "$VERSIONED_TAG" .; then
    print_success "Docker image built successfully: $VERSIONED_TAG"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Tag the image with latest
print_status "Tagging image with latest tag..."
if docker tag "$VERSIONED_TAG" "$LATEST_TAG"; then
    print_success "Image tagged successfully: $LATEST_TAG"
else
    print_error "Failed to tag image with latest"
    exit 1
fi

# Login to Docker registry
print_status "Logging in to Docker registry: $DOCKER_REGISTRY"
if echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" --username "$DOCKER_USERNAME" --password-stdin; then
    print_success "Successfully logged in to Docker registry"
else
    print_error "Failed to login to Docker registry"
    exit 1
fi

# Push the versioned image
print_status "Pushing versioned image: $VERSIONED_TAG"
if docker push "$VERSIONED_TAG"; then
    print_success "Successfully pushed versioned image: $VERSIONED_TAG"
else
    print_error "Failed to push versioned image"
    exit 1
fi

# Push the latest image
print_status "Pushing latest image: $LATEST_TAG"
if docker push "$LATEST_TAG"; then
    print_success "Successfully pushed latest image: $LATEST_TAG"
else
    print_error "Failed to push latest image"
    exit 1
fi

# Logout from Docker registry
print_status "Logging out from Docker registry..."
docker logout "$DOCKER_REGISTRY" || print_warning "Logout failed, but continuing..."

# Summary
print_success "=== BUILD AND PUSH COMPLETED SUCCESSFULLY ==="
print_success "Images pushed:"
print_success "  - $VERSIONED_TAG"
print_success "  - $LATEST_TAG"
print_success "Build timestamp: $TIMESTAMP"
print_success "Git commit: $GIT_COMMIT"