#!/bin/bash

############################
# SSL Certificate Creation #
############################

TMP="$(dirname "$(realpath "$0")")/../tmp"
ENV="$(dirname "$(realpath "$0")")/../.env"
SSL_CONF="$(dirname "$(realpath "$0")")/../config/nginx/openssl.cnf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

create_self_signed_cert() {
    while [[ ! -f "$SSL_CONF" ]]; do
        error "OpenSSL configuration file ($SSL_CONF) not found!"

        echo -e "${YELLOW}Please create or update the OpenSSL configuration file at the specified path.${NC}"
        echo -e "${YELLOW}You can duplicate your terminal session, make the necessary changes, and come back here.${NC}"
        echo -e "${YELLOW}Press 'r' to retry or 'q' to quit.${NC}"
        read -r choice

        case $choice in
            [Rr])
                log "Retrying..."
                ;;
            [Qq])
                error "Exiting script. Please configure the OpenSSL file and rerun the script."
                exit 1
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 'r' to retry or 'q' to quit.${NC}"
                ;;
        esac
    done

    log "Using OpenSSL configuration file: $SSL_CONF"
    openssl req -x509 -nodes -days 730 -newkey rsa:4096 \
        -keyout "$TMP/private.key" \
        -out "$TMP/certificate.crt" \
        -config "$SSL_CONF" || error "Failed to create self-signed certificate"
    log "Self-signed certificate created at $TMP"
}

main() {
    log "Creating SSL certificates..."
    load_env
    create_self_signed_cert
}

main "$@"

