#!/bin/bash

##########################################
# Main Deployment Script for Vaultwarden #
##########################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV=".env"
TMP="tmp"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
	
    # Check for .env file
    if [ ! -f $ENV ]; then
        error "$ENV file not found. Please create one from $ENV.example"
    fi

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi

    # Check if docker group exists
    if ! getent group docker > /dev/null; then
        log "Creating docker group..."
        sudo groupadd docker
    else
        log "Docker group already exists."
    fi

    # Check if $USER is in docker group
    if groups "$USER" | grep -q "\bdocker\b"; then
        log "$USER is already in the docker group."
    else
        log "Adding $USER to the docker group..."
        sudo usermod -aG docker "$USER"
	newgrp docker
    fi

    # Check if /usr/bin/docker has correct group ownership
    current_group=$(stat -c '%G' /usr/bin/docker)
    if [ "$current_group" != "docker" ]; then
        log "Changing group ownership of /usr/bin/docker to docker..."
        sudo chown root:docker /usr/bin/docker
    else
        log "Group ownership of /usr/bin/docker is already set to docker."
    fi

    # Check if permissions on /usr/bin/docker are correct
    current_permissions=$(stat -c '%A' /usr/bin/docker)
    if [ "$current_permissions" != "rwxr-x---" ]; then
        log "Setting correct permissions for /usr/bin/docker..."
        sudo chmod 750 /usr/bin/docker
    else
        log "Permissions on /usr/bin/docker are already correct."
    fi
}

set_volume_directory() {
    if [ ! -d /opt/vaultwarden ]; then    
    	log "Creating necessary directories..."
	sudo mkdir -p /opt/vaultwarden /opt/vaultwarden/backups /opt/vaultwarden/logs &> /dev/null
    fi
    # Set permissions
    sudo chown -R root:docker /opt/vaultwarden
    sudo chmod 750 /opt/vaultwarden
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
        echo -e "${YELLOW}Do you have existing SSL certificates? ([y]es/[n]o)${NC}"
        read -r existing_cert
        if [[ "$existing_cert" =~ ^(yes|y)$ ]]; then
	    export EXISTING_CERT=true
            echo -e "${YELLOW}Enter the path to your certificate file:${NC}"
            read -r cert_file
	    export CERTIFICATE="${cert_file}"
            echo -e "${YELLOW}Enter the path to your private key file:${NC}"
            read -r pvt_key_file
	    export PRIVATE_KEY="${pvt_key_file}"
        else
	    export EXISTING_CERT=false
	    mkdir $TMP
            ./scripts/ssl-cert-create.sh || error "Failed to create certificates"
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

    source "$ENV"
    if [[ -z "${DOCKER_NET}" ]]; then
        sed -i '/^DOCKER_NET=/d' $ENV || error "Failed to remove empty DOCKER_NET entry"
        echo -e "${YELLOW}Enter a name for the Docker network (e.g., 'vault-net'):${NC}"
	read -r vault_net

        if [[ -z "${vault_net}" ]]; then
            error "Docker network name cannot be empty"
        fi

        export VAULT_NET="${vault_net}"
        echo "DOCKER_NET=${VAULT_NET}" >> $ENV || error "Failed to update .env with DOCKER_NET"
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
    docker compose -f config/docker/vw-compose.yml --env-file $ENV pull
    docker compose -f config/docker/vw-compose.yml --env-file $ENV up -d || error "Failed to start containers"
}

main() {
    log "Starting Vaultwarden deployment..."
    check_prerequisites
    set_volume_directory
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
    ./scripts/bw-cli-config.sh || echo "Bitwarden CLI could not be configured..."
    echo -e "${YELLOW}Please check the README.md file for post-installation steps and security considerations${NC}"
}

main "$@"
