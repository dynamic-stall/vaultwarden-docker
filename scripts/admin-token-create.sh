#!/bin/bash

set -e

ENV=".env"
MIN_PASS_LENGTH=12
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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

validate_password() {
    local password=$1
    
    if [ ${#password} -lt $MIN_PASS_LENGTH ]; then
        return 1
    fi
    
    if ! echo "$password" | grep -q "[A-Z]"; then
        return 1
    fi
    if ! echo "$password" | grep -q "[a-z]"; then
        return 1
    fi
    if ! echo "$password" | grep -q "[0-9]"; then
        return 1
    fi
    if ! echo "$password" | grep -q "[!@#$%^&*()_+]"; then
        return 1
    fi
    
    return 0
}

install_argon2() {
    log "Checking for Argon2..."
    if ! command -v argon2 &> /dev/null; then
        log "Installing Argon2..."
        sudo dnf install -y argon2 || error "Failed to install Argon2. Please install it manually."
    else
        log "Argon2 is already installed."
    fi
}

backup_env() {
    if [ -f "$ENV" ]; then
        log "Creating backup of existing .env file..."
        cp "$ENV" "${ENV}${BACKUP_SUFFIX}" || \
            error "Failed to create backup of .env file"
    fi
}

main() {
    load_env
    install_argon2
    backup_env

    if grep -q '^ADMIN_TOKEN' "$ENV"; then
        current_value=$(grep '^ADMIN_TOKEN' "$ENV" | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/^"//' -e 's/"$//')

        if [ -z "$current_value" ]; then
            log "Existing 'ADMIN_TOKEN' entry found with no value. Deleting the line."
            sed -i '/^ADMIN_TOKEN/d' "$ENV"
        else
            while true; do
                echo -e "${YELLOW}An existing 'ADMIN_TOKEN' entry is present in the .env file:${NC}"
                echo -e "${CYAN}Current value: ${current_value}${NC}"
                read -p "Do you want to overwrite this value? ([y]es/[n]o): " choice
                case "$choice" in
                    y|yes)
                        log "Overwriting the existing 'ADMIN_TOKEN'."
                        sed -i '/^ADMIN_TOKEN/d' "$ENV"
                        break
                        ;;
                    n|no)
                        log "Skipping admin token creation process."
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}Invalid input. Please enter 'y'|'yes' or 'n'|'no'.${NC}"
                        ;;
                esac
            done
        fi
    fi

    while true; do
        read -s -p "Enter Vaultwarden admin token password: " PASSWORD
        echo
        read -s -p "Confirm password: " PASSWORD2
        echo
        
        if [ "$PASSWORD" != "$PASSWORD2" ]; then
            echo -e "${YELLOW}Passwords don't match. Please try again.${NC}"
            continue
        fi
        
        if ! validate_password "$PASSWORD"; then
            echo -e "${YELLOW}Password must be at least $MIN_PASS_LENGTH characters long and contain uppercase, lowercase, numbers, and special characters.${NC}"
            continue
        fi
        
        break
    done
    
    log "Generating secure salt..."
    SALT=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)
    
    log "Generating password hash..."
    HASH=$(echo -n "$PASSWORD" | argon2 "$SALT" -id -t 3 -m 15 -p 4 -l 32 -e)
    
    log "Updating .env file..."
    if [ -f "$ENV" ]; then
        sed -i '/^ADMIN_TOKEN=/d' "$ENV"
    fi

    echo "ADMIN_TOKEN=\"$(echo "$HASH" | sed 's/\$/\$\$/g')\"" >> "$ENV"
    
    log "Admin token successfully generated and stored in .env file"
    echo -e "${YELLOW}Backup created at ${ENV}${BACKUP_SUFFIX}${NC}"
}

main "$@"