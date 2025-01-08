#!/bin/bash

#########################################
# Configuration for Nginx Reverse Proxy #
#########################################

set -e
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TMP="$(dirname "$(realpath "$0")")/../tmp"
SSL_DIR="/etc/nginx/ssl"
ENV="$(dirname "$(realpath "$0")")/../.env"
BW_CONF="$(dirname "$(realpath "$0")")/../config/nginx/bitwarden.conf.template"
NGX_CONF="/etc/nginx/conf.d/bitwarden.conf"
DOMAIN="$(grep -oP '^BW_DOMAIN=\K.*' $ENV)"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

load_env() {
    if [[ -f $ENV ]]; then
        source "$ENV"
        log "Environment variables loaded from $ENV"
    else
        error "Environment file ($ENV) not found!"
    fi
}

install_nginx() {
    log "Checking for Nginx..."

    if ! command -v nginx &> /dev/null; then
        log "Nginx not found. Installing Nginx and dependencies..."
        sudo dnf install epel-release -y || error "Failed to install EPEL"
        sudo dnf install nginx -y || error "Failed to install Nginx"
        log "Nginx installation completed successfully."
    else
        log "Nginx is already installed. Skipping installation..."
    fi
}

configure_firewall() {
    log "Configuring firewall..."
    
    sudo firewall-cmd --permanent --zone=public --add-service=https || error "Failed to add HTTPS to firewall"
    sudo firewall-cmd --permanent --zone=public --add-service=http || error "Failed to add HTTP to firewall"
    sudo firewall-cmd --reload || error "Failed to reload firewall"
}

configure_nginx() {
    log "Configuring Nginx..."
    
    sudo mkdir -p $SSL_DIR
    
    # Copy certificates
    if [[ "$EXISTING_CERT" == "true" ]]; then
        sudo ln -s $CERTIFICATE $SSL_DIR/certificate.crt || error "Failed to create symlink to SSL certificate"
	sudo ln -s $PRIVATE_KEY $SSL_DIR/private.key || error "Failed to create symlink to private key file"
    else
        sudo cp $TMP/* $SSL_DIR/ || error "Failed to copy SSL certificates"
    fi

    # Generate Nginx configuration file using envsubst
    envsubst "$DOMAIN" < "${BW_CONF}" | sudo tee "$NGX_CONF" || error "Failed to generate Nginx configuration"

    # Check if the 'nginx' group exists
    if ! getent group nginx &> /dev/null; then
        echo "Nginx group does not exist. Creating nginx group..."
        sudo groupadd nginx
    fi

    # Ensure the current user is added to the nginx group
    if ! groups $USER | grep -q "\bnginx\b"; then
        echo "Adding $USER to the nginx group..."
        sudo usermod -aG nginx $USER
    fi

    # Ensure proper permissions/ownership for nginx binaries
    sudo chown -R root:nginx /etc/nginx
    sudo chmod 750 /etc/nginx
    sudo chmod 750 /etc/nginx/ssl
    sudo chmod 640 /etc/nginx/ssl/private.key
    sudo chmod 644 /etc/nginx/ssl/certificate.crt

    # Test configuration
    sudo nginx -t || error "Nginx configuration test failed"

    # Restart Nginx
    sudo systemctl restart nginx || error "Failed to restart Nginx"
}

verify_ssl_setup() {
    log "Verifying SSL setup..."
    
    # Check if all required files exist
    local required_files=("$SSL_DIR/private.key" "$SSL_DIR/certificate.crt")
    for file in "${required_files[@]}"; do
        if [ ! -f "$SSL_DIR/$file" ]; then
            echo -e "${YELLOW}Warning: $file not found in $SSL_DIR${NC}"
        fi
    done
}

main() {
    log "Starting Nginx configuration..."
    load_env
    install_nginx
    configure_firewall
    configure_nginx
    verify_ssl_setup
    
    log "Nginx configuration completed successfully"
    
    if [ "$ENABLE_SSL" = "true" ] && [ -n "$BW_DOMAIN" ]; then
        echo -e "${YELLOW}If registering SSL certs with Cloudflare, don't forget to:"
        echo "1. Submit the CSR to Cloudflare"
        echo "2. Place the Cloudflare-issued certificate in the $SSL_DIR directory"
        echo -e "3. Restart Nginx after installing the certificate${NC}"
    fi
}

main "$@"
