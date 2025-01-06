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
            read -r CERT_FILE
            echo -e "${YELLOW}Enter the path to your private key file:${NC}"
            read -r PRIVATE_KEY_FILE

            sudo cp $CERT_FILE $PRIVATE_KEY_FILE $TMP/
        else
            ./scripts/ssl-certs-create.sh || error "Failed to create certificates"
        fi

        echo -e "${YELLOW}Do you want to register your certificates with Cloudflare? ([y]es/[n]o)${NC}"
        read -r register_cloudflare

        if [[ "$register_cloudflare" =~ ^(yes|y)$ ]]; then
            ./scripts/cloudflare-cert-register.sh || error "Failed to register certificates with Cloudflare"
        else
            log "Skipping Cloudflare registration. Proceeding to Nginx configuration."
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
    if ! docker network inspect ${DOCKER_NET} > /dev/null 2>&1; then
        docker network create --subnet=172.20.0.0/16 ${DOCKER_NET} || error "Failed to create Docker network"
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
    if [[ "$ENABLE_SSL" == "true" ]]; then
        configure_nginx
    fi
    setup_docker_network
    deploy_containers
    rm -rf $TMP
    log "Deployment completed successfully!"
    echo -e "${YELLOW}Please check the README for post-installation steps and security considerations${NC}"
}

main "$@"
