#!/bin/bash

# deploy.sh - Main deployment script for Vaultwarden

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    }
    
    # Check for .env file
    if [ ! -f .env ]; then
        error ".env file not found. Please create one from .env.example"
    }
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p /opt/bitwarden
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /etc/nginx/ssl
    
    # Set proper permissions
    chmod 750 /opt/bitwarden
}

# Generate admin token
generate_admin_token() {
    log "Generating admin token..."
    
    ./scripts/admin-token-create.sh || error "Failed to generate admin token"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    ./scripts/nginx-config.sh || error "Failed to configure Nginx"
}

# Create Docker network if it doesn't exist
setup_docker_network() {
    log "Setting up Docker network..."
    
    source .env
    if ! docker network inspect ${DOCKER_NET} >/dev/null 2>&1; then
        docker network create --subnet=172.20.0.0/16 ${DOCKER_NET} || error "Failed to create Docker network"
    fi
}

# Deploy containers
deploy_containers() {
    log "Deploying containers..."
    
    docker compose -f config/docker/bw-compose.yml pull
    docker compose -f config/docker/bw-compose.yml up -d || error "Failed to start containers"
}

# Main execution
main() {
    log "Starting Vaultwarden deployment..."
    
    check_prerequisites
    create_directories
    generate_admin_token
    configure_nginx
    setup_docker_network
    deploy_containers
    
    log "Deployment completed successfully!"
    echo -e "${YELLOW}Please check the README for post-installation steps and security considerations${NC}"
}

main "$@"
