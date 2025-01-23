#!/bin/bash

##########################################
# Main Deployment Script for Vaultwarden #
##########################################

set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
PURPLE="\033[0;35m"
CYAN="\033[1;36m"
ORANGE="\033[38;5;202m"
BOLD="\033[1m"
NC="\033[0m"

ENV=".env"
TMP="tmp"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    sleep 1s
}

prompt() {
    echo -e "${YELLOW}$1${NC}"
    sleep 1.25s
}

success() {
    echo -e "${CYAN}[SUCCESS] $1${NC}"
    sleep 2s
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 2
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
        log "User $USER is already in the docker group."
    else
        log "Adding user $USER to the docker group..."
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

    # Check if jq, ipcalc is installed
    for pkg in "jq" "ipcalc"; do
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${ORANGE}'$pkg' is required for Docker network validation. Installing...${NC}"
            sleep 1.25s
            if sudo dnf install -y "$pkg" &> /dev/null; then
                success "'$pkg' installed successfully."
            else
                error "'$pkg' could not be installed. Please install manually."
            fi
        fi
    done
}

set_volume_directory() {
    if [ ! -d /opt/vaultwarden ]; then    
    	log "Creating necessary directories..."
        # Back-ups directory
	    sudo mkdir -p /opt/vaultwarden /opt/vaultwarden/backups /opt/vaultwarden/logs &> /dev/null
        # Favicon directory (see: config/docker/favicon.ico)
        #sudo mkdir -p /opt/vaultwarden/web-vault/static &> /dev/null
    fi
    # Set permissions
    sudo chown -R root:docker /opt/vaultwarden
    sudo chmod -R 750 /opt/vaultwarden
}

generate_admin_token() {
    log "Generating admin token..."
    ./scripts/admin-token-create.sh || error "Failed to generate admin token"
}

deploy_containers() {
    log "Deploying containers..."
    docker compose -f config/docker/vw-compose.yml --env-file $ENV pull || error "Failed to update Docker image."
    docker compose -f config/docker/vw-compose.yml --env-file $ENV up -d || error "Failed to start containers."
}

main() {
    log "Starting Vaultwarden deployment..."
    check_prerequisites
    set_volume_directory
    generate_admin_token
    deploy_containers
    success "Vault deployment completed!"
    ./scripts/bw-cli-config.sh || echo "Bitwarden CLI could not be configured..."
    prompt "Please check the README for post-installation steps and security considerations."
}

main "$@"
