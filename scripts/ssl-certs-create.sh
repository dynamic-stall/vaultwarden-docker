#!/bin/bash

############################
# SSL Certificate Creation #
############################

TMP="../tmp"
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

create_self_signed_cert() {
    openssl req -x509 -nodes -days 730 -newkey rsa:4096 \
        -keyout $TMP/private.key \
        -out $TMP/certificate.crt \
        -subj CN=localhost
    log "Self-signed certificate created at $TMP"
}

main() {
    log "Creating SSL certificates..."
    create_self_signed_cert
}

main "$@"

