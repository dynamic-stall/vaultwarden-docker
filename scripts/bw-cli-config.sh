#!/bin/bash

###########################################
# Bitwarden CLI Install and Configuration #
###########################################

ENV="../.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to log messages
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

# Check if bw CLI is installed
check_bw_cli() {
    if ! command -v bw &> /dev/null; then
        echo -e "${YELLOW}Bitwarden CLI not found. Would you like to install it? (y/n)${NC}"
        read -r install_choice
        
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            if command -v npm &> /dev/null; then
                log "Installing Bitwarden CLI via npm..."
                npm install -g @bitwarden/cli
            elif command -v snap &> /dev/null; then
                log "Installing Bitwarden CLI via snap..."
                sudo snap install bw
            else
                error "Neither npm nor snap found. Please install Bitwarden CLI manually from: https://bitwarden.com/help/cli/"
            fi
        else
            error "Bitwarden CLI is required for configuration"
        fi
    fi
}

# Configure Bitwarden CLI
configure_cli() {
    local base_url="https://$BW_DOMAIN"
    
    log "Configuring Bitwarden CLI for domain: $BW_DOMAIN"
    
    # Set base server URL
    bw config server "$base_url"
    
    # Configure individual endpoints
    bw config server \
        --api "$base_url/api" \
        --identity "$base_url/identity" \
        --web-vault "$base_url" \
        --icons "$base_url/icons" \
        --notifications "$base_url/notifications" \
        --events "$base_url/events"
    
    # Verify configuration
    log "Current Bitwarden CLI configuration:"
    bw config server
}

# Main execution
main() {
    log "Starting Bitwarden CLI configuration..."
    load_env
    check_bw_cli
    configure_cli    
    log "Configuration completed successfully!"
    echo -e "${YELLOW}You can now login using: bw login${NC}"
}

main "$@"
