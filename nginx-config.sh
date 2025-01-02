#!/bin/bash

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SSL_DIR="/etc/nginx/ssl"
SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONF="/etc/nginx/nginx.conf"
CLOUDFLARE_CERTS_URL="https://developers.cloudflare.com/ssl/static/origin_ca_rsa_root.pem"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
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

# Function to install Nginx
install_nginx() {
    log "Installing Nginx and dependencies..."
    
    if command -v dnf &> /dev/null; then
        sudo dnf install epel-release -y || error "Failed to install EPEL"
        sudo dnf install nginx curl -y || error "Failed to install Nginx and curl"
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install nginx curl -y || error "Failed to install Nginx and curl"
    else
        error "Unsupported package manager"
    fi
}

# Function to configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --zone=public --add-service=https || error "Failed to add HTTPS to firewall"
        sudo firewall-cmd --permanent --zone=public --add-service=http || error "Failed to add HTTP to firewall"
        sudo firewall-cmd --reload || error "Failed to reload firewall"
    elif command -v ufw &> /dev/null; then
        sudo ufw allow 'Nginx Full' || error "Failed to configure UFW"
    fi
}

# Function to download Cloudflare certificates
download_cloudflare_certs() {
    log "Downloading Cloudflare certificates..."
    
    # Create SSL directory if it doesn't exist
    sudo mkdir -p "$SSL_DIR"
    
    # Download Cloudflare's Origin CA certificate
    if ! sudo curl -sS "$CLOUDFLARE_CERTS_URL" -o "$SSL_DIR/cloudflare.pem"; then
        error "Failed to download Cloudflare certificates"
    fi
    
    # Verify the certificate was downloaded
    if [ ! -f "$SSL_DIR/cloudflare.pem" ]; then
        error "Cloudflare certificate file not found after download"
    fi
    
    # Set proper permissions
    sudo chmod 644 "$SSL_DIR/cloudflare.pem"
}

# Function to create SSL certificates
create_ssl_certs() {
    log "Creating SSL certificates..."
    
    # Create SSL directory if it doesn't exist
    sudo mkdir -p "$SSL_DIR"
    
    if [ "$ENABLE_SSL" = "true" ]; then
        if [ -z "$BW_DOMAIN" ]; then
            # Generate self-signed certificate
            log "Generating self-signed certificate..."
            sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
                -keyout "$SSL_DIR/private.key" \
                -out "$SSL_DIR/certificate.crt" \
                -subj "/C=$SSL_COUNTRY/ST=$SSL_STATE/L=$SSL_LOCALITY/O=$SSL_ORG/CN=$SSL_CN" \
                || error "Failed to generate self-signed certificate"
        else
            # Generate CSR for domain
            log "Generating CSR for domain $BW_DOMAIN..."
            sudo openssl req -new -newkey rsa:4096 -nodes \
                -keyout "$SSL_DIR/private.key" \
                -out "$SSL_DIR/request.csr" \
                -subj "/C=$SSL_COUNTRY/ST=$SSL_STATE/L=$SSL_LOCALITY/O=$SSL_ORG/CN=$BW_DOMAIN" \
                || error "Failed to generate CSR"
            
            echo -e "${YELLOW}CSR generated at $SSL_DIR/request.csr"
            echo -e "Please submit this CSR to Cloudflare and place the certificate at $SSL_DIR/certificate.crt${NC}"
        fi
    fi
    
    # Set proper permissions for SSL files
    sudo chmod 600 "$SSL_DIR/private.key"
    [ -f "$SSL_DIR/certificate.crt" ] && sudo chmod 644 "$SSL_DIR/certificate.crt"
}

# Function to configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Create required directories
    sudo mkdir -p "$SITES_AVAILABLE" "$SITES_ENABLED"
    
    # Copy configuration files
    sudo cp bitwarden.conf "$SITES_AVAILABLE/" || error "Failed to copy Nginx configuration"
    
    # Create symlink if it doesn't exist
    if [ ! -L "$SITES_ENABLED/bitwarden.conf" ]; then
        sudo ln -s "$SITES_AVAILABLE/bitwarden.conf" "$SITES_ENABLED/" || error "Failed to create symlink"
    fi
    
    # Test configuration
    sudo nginx -t || error "Nginx configuration test failed"
    
    # Restart Nginx
    sudo systemctl restart nginx || error "Failed to restart Nginx"
}

# Function to verify SSL setup
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

# Main function
main() {
    log "Starting Nginx configuration..."
    
    install_nginx
    configure_firewall
    download_cloudflare_certs
    create_ssl_certs
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
