#!/bin/bash

##########################################
# Main Deployment Script for Vaultwarden #
##########################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TMP="./tmp/"

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

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    # Check for .env file
    if [ ! -f .env ]; then
        error ".env file not found. Please create one from .env.example"
    fi
}

create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p /opt/bitwarden
    
    # Set proper permissions
    chmod 750 /opt/bitwarden
}

generate_admin_token() {
    log "Generating admin token..."
    ./scripts/admin-token-create.sh || error "Failed to generate admin token"
}

setup_ssl() {
    echo -e "${YELLOW}Do you want to enable SSL? ([y]es/[n]o)${NC}"
    read -r enable_ssl
    if [[ "$enable_ssl" =~ ^(yes|y)$ ]]; then
        export ENABLE_SSL=true
        mkdir $TMP
        echo -e "${YELLOW}Do you have existing SSL certificates? ([y]es/[n]o)${NC}"
        read -r existing_cert

        if [[ "$existing_cert" =~ ^(yes|y)$ ]]; then
            echo -e "${YELLOW}Enter the path to your certificate file:${NC}"
            read -r cert_file
	    export CERTIFICATE=cert_file
            echo -e "${YELLOW}Enter the path to your private key file:${NC}"
            read -r pvt_key_file
	    export PRIVATE_KEY=pvt_key_file

            sudo cp $CERTIFICATE $PRIVATE_KEY $TMP/
        else
            ./scripts/ssl-cert-create.sh || error "Failed to create certificates"
	    export CERTIFICATE="/etc/nginx/ssl/certificate.crt"
	    export PRIVATE_KEY="/etc/nginx/ssl/private.key"
        fi
    else
        export ENABLE_SSL=false
        log "SSL disabled. Skipping SSL setup."
    fi
}

configure_nginx() {
    if [[ "$ENABLE_SSL" == "true" ]]; then
        log "Configuring Nginx..."
        ./scripts/nginx-config.sh || error "Failed to configure Nginx"
    else
        log "SSL disabled. Skipping Nginx configuration."
    fi
}

setup_docker_network() {
    log "Setting up Docker network..."

    source .env
    if [[ -z "${DOCKER_NET}" ]]; then
        sed -i '/^DOCKER_NET=/d' .env || error "Failed to remove empty DOCKER_NET entry"
        echo -e "${YELLOW}Enter a name for the Docker network (e.g., 'vault-net'):${NC}"
	read -r vault_net

        if [[ -z "${vault_net}" ]]; then
            error "Docker network name cannot be empty"
        fi

        export VAULT_NET="${vault_net}"
        echo "DOCKER_NET=${VAULT_NET}" >> .env || error "Failed to update .env with DOCKER_NET"
        log "DOCKER_NET set to '${VAULT_NET}' and updated in .env file"
    fi

    if ! docker network inspect "${DOCKER_NET}" > /dev/null 2>&1; then
        ./scripts/docker-custom-net.sh || error "Failed to create Docker network."
        log "Docker network '${DOCKER_NET}' created successfully"
    else
        log "Docker network '${DOCKER_NET}' already exists. No action required."
    fi
}

deploy_containers() {
    log "Deploying containers..."
    docker compose -f config/docker/bw-compose.yml pull
    docker compose -f config/docker/bw-compose.yml up -d || error "Failed to start containers"
}

main() {
    log "Starting Vaultwarden deployment..."
    check_prerequisites
    create_directories
    generate_admin_token
    setup_ssl
    configure_nginx
    echo -e "${YELLOW}Are you using an existing Docker network? ([y]es/[n]o):${NC}"
    read -r use_existing_network
    if [[ "$use_existing_network" =~ ^(yes|y)$ ]]; then
	log "Using an existing Docker network. Ensure that the .env file is configured correctly."
    else
	setup_docker_network
    fi
    deploy_containers
    rm -rf $TMP
    log "Deployment completed successfully!"
    echo -e "${YELLOW}Please check the README for post-installation steps and security considerations${NC}"
}

main "$@"
