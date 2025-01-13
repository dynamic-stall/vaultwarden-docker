#!/bin/bash

###########################################
# Bitwarden CLI Install and Configuration #
###########################################

ENV="$(dirname "$(realpath "$0")")/../.env"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
ORANGE="\033[38;5;202m"
NC="\033[0m"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    return 1
}

warning() {
    echo -e "${ORANGE}[WARNING] $1${NC}"
    echo "Please check official CLI documentation: https://bitwarden.com/help/cli"
    return 1
}

load_env() {
    if [[ -f $ENV ]]; then
        source "$ENV"
        log "Environment variables loaded from $ENV"
    else
        error "Environment file ($ENV) not found!"
    fi
}

check_bw_cli() {
    log "Checking for Bitwarden CLI..."
    if ! command -v bw &> /dev/null; then
        echo -e "${YELLOW}Would you like to install the Bitwarden CLI? ([y]es/[n]o)${NC}"
        read -r install_choice

        if [[ $install_choice =~ ^(yes|y)$ ]]; then
            if ! command -v npm &> /dev/null; then
                log "npm not found. Installing npm..."
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y npm || warning "Failed to install npm. Install it manually from: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm"
                else
                    warning "Unsupported package manager. Install npm manually from: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm"
                fi
            fi

            log "Installing Bitwarden CLI via npm..."
            if npm install -g @bitwarden/cli; then
                log "Bitwarden CLI successfully installed via npm."
            else
                warning "Failed to install Bitwarden CLI via npm."
            fi
        else
            echo "Bitwarden CLI will not be installed. Exiting..."
            return 0
        fi
    else
        log "Bitwarden CLI is already installed."
    fi
}

configure_cli() {
    local base_url="https://$BW_DOMAIN"

    log "Configuring Bitwarden CLI for domain: $BW_DOMAIN"

    # Set base server URL
    bw config server "$base_url" || warning "Unable to configure Bitwarden CLI."
    
    # Configure individual endpoints
    bw config server \
        --api "$base_url/api" \
        --identity "$base_url/identity" \
        --web-vault "$base_url" \
        --icons "$base_url/icons" \
        --notifications "$base_url/notifications" \
        --events "$base_url/events" || warning "Unable to configure Bitwarden CLI."

    # Verify configuration
    log "Current Bitwarden CLI configuration:"
    bw config server
}

main() {
    log "Starting Bitwarden CLI configuration..."
    load_env
    check_bw_cli
    configure_cli
    log "Configuration completed successfully!"
    echo -e "${YELLOW}You can now login using: '${NC}bw login${YELLOW}'${NC}"
}

main "$@"
