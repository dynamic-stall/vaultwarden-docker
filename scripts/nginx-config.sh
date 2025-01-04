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

TMP="../tmp"
SSL_DIR="/etc/nginx/ssl"
ENV="../.env"
BW_CONF="../config/nginx"
NGX_CONF="/etc/nginx/conf.d"
CLOUDFLARE_CERTS_URL="https://developers.cloudflare.com/ssl/static/origin_ca_rsa_root.pem"

# Load environment variables
if [ -f "$ENV" ]; then
    source "$ENV"
else
    echo -e "${RED}Error: "$ENV" file not found${NC}"
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

install_nginx() {
    log "Installing Nginx and dependencies..."
    
    if ! command -v nginx &> /dev/null; then
        sudo dnf install epel-release -y || error "Failed to install EPEL"
        sudo dnf install nginx -y || error "Failed to install Nginx"
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
    
    # Copy configuration files and certificates
    sudo cp $BW_CONF/bitwarden.conf $NGX_CONF/ || error "Failed to copy Nginx configuration"
    sudo cp $TMP/* $SSL_DIR/ || error "Failed to copy SSL certificates"
    
    # Test configuration
    sudo nginx -t || error "Nginx configuration test failed"
    
    # Restart Nginx
    sudo systemctl restart nginx || error "Failed to restart Nginx"
}

verify_ssl_setup() {
    log "Verifying SSL setup..."
    
    # Check if all required files exist
    local required_files=("private.key" "certificate.crt" "cloudflare.pem")
    for file in "${required_files[@]}"; do
        if [ ! -f "$SSL_DIR/$file" ]; then
            echo -e "${YELLOW}Warning: $file not found in $SSL_DIR${NC}"
        fi
    done
    
    # Verify certificate chain
    if [ -f "$SSL_DIR/certificate.crt" ] && [ -f "$SSL_DIR/cloudflare.pem" ]; then
        if ! openssl verify -CAfile "$SSL_DIR/cloudflare.pem" "$SSL_DIR/certificate.crt" > /dev/null 2>&1; then
            echo -e "${YELLOW}Warning: SSL certificate chain verification failed${NC}"
        fi
    fi
}

main() {
    log "Starting Nginx configuration..."
    
    install_nginx
    configure_firewall
    configure_nginx
    verify_ssl_setup
    
    log "Nginx configuration completed successfully"
    
    if [ "$ENABLE_SSL" = "true" ] && [ -n "$BW_DOMAIN" ]; then
        echo -e "${YELLOW}Don't forget to:"
        echo "1. Submit the CSR to Cloudflare"
        echo "2. Place the Cloudflare-issued certificate at $SSL_DIR/certificate.crt"
        echo -e "3. Restart Nginx after installing the certificate${NC}"
    fi
}

main "$@"
