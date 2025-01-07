#!/bin/bash

set -e

# Configuration
ENV="$(dirname "$(realpath "$0")")/../.env"
MIN_PASS_LENGTH=12
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

# Color codes
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

# Function to validate password strength
validate_password() {
    local password=$1
    
    # Check length
    if [ ${#password} -lt $MIN_PASS_LENGTH ]; then
        return 1
    fi
    
    # Check for uppercase, lowercase, numbers, and special characters
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

# Check if Argon2 is installed
install_argon2() {
    log "Checking for Argon2..."
    if ! command -v argon2 &> /dev/null; then
        log "Installing Argon2..."
        sudo dnf install -y argon2
    else
        error "Package manager not supported. Please install Argon2 manually from: https://www.npmjs.com/package/argon2"
    fi
}

# Backup existing .env file
backup_env() {
    if [ -f "$ENV" ]; then
        log "Creating backup of existing .env file..."
        cp "$ENV" "${ENV}${BACKUP_SUFFIX}" || \
            error "Failed to create backup of .env file"
    fi
}

# Main function
main() {
    load_env
    install_argon2
    backup_env
    
    # Get password with verification
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
    
    # Generate cryptographically secure salt
    log "Generating secure salt..."
    SALT=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)
    
    # Generate hash with Argon2id
    log "Generating password hash..."
    HASH=$(echo -n "$PASSWORD" | argon2 "$SALT" -id -t 3 -m 15 -p 4 -l 32 | grep 'Hash:' | cut -d' ' -f2)
    
    # Update .env file
    log "Updating .env file..."
    if [ -f "$ENV" ]; then
        sed -i '/^ADMIN_TOKEN=/d' "$ENV"
    fi
    echo "ADMIN_TOKEN=$HASH" >> "$ENV"
    
    log "Admin token successfully generated and stored in .env file"
    echo -e "${YELLOW}Backup created at ${ENV}${BACKUP_SUFFIX}${NC}"
}

main "$@"
