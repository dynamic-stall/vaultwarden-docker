#!/bin/bash

#############################################
# Register SSL Certificates with Cloudflare #
#############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TMP="../tmp"
ENV="../.env"

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to check if file exists and is readable
check_file() {
    if [ ! -f "$1" ] || [ ! -r "$1" ]; then
        error "File $1 does not exist or is not readable"
    fi
}

# Function to get Cloudflare zones
get_zones() {
    log "Fetching Cloudflare zones..."
    docker run --rm \
        -e CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
        cloudflare/cloudflared zones list
}

# Function to validate zone ID
validate_zone_id() {
    local zone_id=$1
    local zones_output
    
    zones_output=$(get_zones)
    if ! echo "$zones_output" | grep -q "\"id\": \"$zone_id\""; then
        error "Invalid zone ID. Please check your Cloudflare dashboard or run: docker run --rm cloudflare/cloudflared zones list"
    fi
}

# Load environment variables
if [ -f "$ENV" ]; then
    source "$ENV"
else
    error "Environment file not found: $ENV"
fi

# Check required environment variables
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    error "CLOUDFLARE_API_TOKEN is not set in $ENV"
fi

if [ -z "$BW_DOMAIN" ]; then
    error "BW_DOMAIN is not set in $ENV"
fi

# Main function
main() {
    local ZONE_ID=$1
    local CERT_TYPE=${2:-"client"}  # Default to client certificate
    local CERT_FILE=${3:-"$TMP/certificate.crt"}
    local PRIVATE_KEY_FILE=${4:-"$TMP/private.key"}
    local CA_BUNDLE_FILE=${5:-"$TMP/cloudflare.pem"}

    # Display usage if no arguments provided
    if [ -z "$ZONE_ID" ]; then
        echo "Usage: $0 <ZONE_ID> [CERT_TYPE] [CERT_FILE] [PRIVATE_KEY_FILE] [CA_BUNDLE_FILE]"
        echo
        echo "Options:"
        echo "  ZONE_ID            : Your Cloudflare zone ID (required)"
        echo "  CERT_TYPE          : Certificate type (default: client)"
        echo "  CERT_FILE          : Path to certificate file (default: $TMP/certificate.crt)"
        echo "  PRIVATE_KEY_FILE   : Path to private key file (default: $TMP/private.key)"
        echo "  CA_BUNDLE_FILE     : Path to CA bundle file (default: $TMP/cloudflare.pem)"
        echo
        echo "To list your zones, run: docker run --rm cloudflare/cloudflared zones list"
        exit 1
    fi

    # Validate files exist
    check_file "$CERT_FILE"
    check_file "$PRIVATE_KEY_FILE"
    check_file "$CA_BUNDLE_FILE"

    # Validate zone ID
    validate_zone_id "$ZONE_ID"

    # Pull latest Cloudflare Docker image
    log "Pulling latest Cloudflare Cloudflared image..."
    docker pull cloudflare/cloudflared:latest

    # Register certificate
    log "Registering certificate for zone $ZONE_ID..."
    docker run --rm \
        -e CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
        -v "$CERT_FILE:/cert.crt:ro" \
        -v "$PRIVATE_KEY_FILE:/private_key.key:ro" \
        -v "$CA_BUNDLE_FILE:/ca_bundle.crt:ro" \
        cloudflare/cloudflared:latest cloudflared certificate register \
        --zone-id "$ZONE_ID" \
        --type "$CERT_TYPE" \
        --cert "/cert.crt" \
        --key "/private_key.key" \
        --bundle "/ca_bundle.crt"

    if [ $? -eq 0 ]; then
        log "Certificate registration completed successfully for zone $ZONE_ID"
        log "Domain: $BW_DOMAIN"
    else
        error "Certificate registration failed"
    fi
}

main "$@"
