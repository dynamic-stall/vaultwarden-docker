#!/bin/bash

############################
# SSL Certificate Creation #
############################

TMP="$(dirname "$(realpath "$0")")/../tmp"
ENV="$(dirname "$(realpath "$0")")/../.env"
SSL_CONF="../config/nginx/openssl.cnf"

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
    if [[ -f "$SSL_CONF" ]]; then
    log "Using OpenSSL configuration file: $SSL_CONF"
    else
        error "OpenSSL configuration file ($SSL_CONF) not found! Please create one using the openssl.cnf.example file found in the config directory."
    fi

    openssl req -x509 -nodes -days 730 -newkey rsa:4096 \
        -keyout "$TMP/private.key" \
        -out "$TMP/certificate.crt" \
        -config "$SSL_CONF"
    log "Self-signed certificate created at $TMP"
}

main() {
    log "Creating SSL certificates..."
    load_env
    create_self_signed_cert
}

main "$@"

