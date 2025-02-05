#!/bin/bash

###########################################
# Bitwarden CLI Install and Configuration #
###########################################

ENV="$(dirname "$(realpath "$0")")/../.env"
DOCKERFILE="$(dirname "$(realpath "$0")")/../config/docker/cli.Dockerfile"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
PURPLE="\033[0;35m"
CYAN="\033[1;36m"
ORANGE="\033[38;5;202m"
NC="\033[0m"

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
    exit 2
}

warning() {
    echo -e "${ORANGE}[WARNING] $1${NC}"
    sleep 1.5s
    echo "Please check official CLI documentation: https://bitwarden.com/help/cli"
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

install_bw_cli() {
    local install_cmd=""
    local package_manager=""

    if command -v npm &> /dev/null; then
        install_cmd="npm install -g @bitwarden/cli"
        package_manager="npm"
    elif command -v snap &> /dev/null; then
        install_cmd="sudo snap install bw"
        package_manager="snap"
    else
        case "$(uname -s)" in
            Linux*)
                if command -v apt &> /dev/null; then
                    install_cmd="sudo apt install bitwarden-cli"
                    package_manager="apt"
                elif command -v dnf &> /dev/null; then
                    install_cmd="sudo dnf install bitwarden-cli"
                    package_manager="dnf"
                elif command -v pacman &> /dev/null; then
                    install_cmd="sudo pacman -S bitwarden-cli"
                    package_manager="pacman"
                else
                    warning "No suitable package manager found. Install Bitwarden CLI manually."
                fi
                ;;
            Darwin*)
                if command -v brew &> /dev/null; then
                  install_cmd="brew install bitwarden-cli"
                  package_manager="brew"
                else
                  warning "No suitable package manager found. Install Bitwarden CLI manually."
                fi
                ;;
            *)
                error "Unsupported operating system."
                ;;
        esac
    fi


    if [[ -n "$install_cmd" ]]; then
        log "Installing Bitwarden CLI via $package_manager..."
        if eval "$install_cmd"; then
            log "Bitwarden CLI successfully installed via $package_manager."
        else
            error "Failed to install Bitwarden CLI via $package_manager. Check the logs for more details."
        fi
    fi
}


check_bw_cli() {
    log "Checking for Bitwarden CLI..."
    if ! command -v bw &> /dev/null; then
        prompt "Would you like to install the Bitwarden CLI? ([y]es/[n]o)"
        read -r install_choice

        if [[ $install_choice =~ ^(yes|y)$ ]]; then
            install_bw_cli
        else
            echo "Bitwarden CLI will not be installed. Exiting..."
            return 0
        fi
    else
        log "Bitwarden CLI is already installed."
    fi
}

configure_bw_cli() {
    log "Configuring Bitwarden CLI for domain: $DOMAIN_URL"

    if bw config server "$DOMAIN_URL"; then
        success "Bitwarden CLI configured successfully!"
        log "Current Bitwarden CLI configuration:"
        bw config server
    else
        warning "Unable to configure Bitwarden CLI."
    fi
}

main() {
    log "Starting Bitwarden CLI configuration..."
    load_env
    check_bw_cli
    configure_bw_cli
    log "Configuration completed successfully!"
    echo -e "${YELLOW}You can now login using: '${NC}bw login${YELLOW}'${NC}"
}

main "$@"
