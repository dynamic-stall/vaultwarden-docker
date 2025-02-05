#!/bin/bash

###########################################
# Bitwarden CLI Install and Configuration #
###########################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[34m"
PURPLE="\033[0;35m"
CYAN="\033[1;36m"
ORANGE="\033[38;5;202m"
BOLD="\033[1m"
NC="\033[0m"

ENV="$(dirname "$(realpath "$0")")/../.env"
CONFIG="$(dirname "$(realpath "$0")")/../config/docker"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    sleep 1s
}

prompt() {
    echo -e "${YELLOW}$1${NC}"
    sleep 1.25s
}

success() {
    echo -e "${CYAN}[SUCCESS] $1${NC}"
    sleep 2s
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    return 2
}

warning() {
    echo -e "${ORANGE}[WARNING] $1${NC}"
    sleep 1.5s
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

build_cli_image() {
    log "Building Bitwarden CLI Docker image..."
    if docker compose -f "$CONFIG/bw-compose.yml" --env-file "$ENV" --profile extras build cli; then
        success "Bitwarden CLI image build complete."
    else
        error "Failed to build Bitwarden CLI image."
    fi
}

main() {
    log "Starting Bitwarden CLI configuration..."
    load_env

    while true; do
        prompt "This script can configure the Bitwarden CLI from a custom Dockerfile, rather than host installation."
        prompt "Would you like to build the Bitwarden CLI Docker image? ([y]es/[n]o)"
        read -r build_choice

        case "${build_choice,,}" in
            y|yes)
                build_cli_image
                echo -e "${YELLOW}You can now run CLI commands with:${NC}\n"
                sleep 0.5s
                echo -e "${PURPLE}docker compose -f $CONFIG/bw-compose.yml run --rm --profile extras cli bw${NC}"
                sleep 2s
                echo -e "${YELLOW}\nTIP: Create a 'bw' alias pointing to 'bw-compose.yml' to quickly access the CLI, i.e.,${NC}\n"
                sleep 0.5s
                echo -e "${BLUE}alias ${CYAN}bw${NC}=${ORANGE}'docker compose -f $HOME/vaultwarden-docker/config/docker/bw-compose.yml run --rm --profile extras cli bw'${NC}\n"
                sleep 2s
                return 0
                ;;
            n|no)
                log "Bitwarden CLI image will not be built."
                prompt "If you prefer, you can install the CLI on your host following instructions at: https://bitwarden.com/help/cli"
                echo -e "${YELLOW}Alternatively, you can install the CLI using the ${CYAN}cli-config-host.sh${YELLOW} script within the scripts directory.${NC}"
                sleep 1.25s
                log "Skipping Bitwarden CLI configuration..."
                return 0
                ;;
            *)
                warning "Invalid input. Please enter 'y', 'yes'; or 'n', 'no'."
                ;;
        esac
    done
}

main "$@"
