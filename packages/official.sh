#!/usr/bin/env bash

# Source required utilities
OFFICIAL_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${OFFICIAL_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install official packages
install_official_packages() {
    log "Installing official packages..."
    local CSV_PATH="${OFFICIAL_SCRIPT_DIR}/programs.csv"
    log "Looking for CSV file at: ${CSV_PATH}"
    
    if [[ ! -f "${CSV_PATH}" ]]; then
        fatal_error "CSV file not found at: ${CSV_PATH}"
        return 1
    fi
    
    local OFFICIAL_PKGS
    OFFICIAL_PKGS=$(awk -F',' '/^official,/ {print $2}' "${CSV_PATH}")
    
    if [[ -z "${OFFICIAL_PKGS}" ]]; then
        fatal_error "No official packages found in CSV file"
        return 1
    fi
    
    log "Found packages: ${OFFICIAL_PKGS}"
    arch-chroot /mnt pacman -S --needed --noconfirm --ask=4 ${OFFICIAL_PKGS} || fatal_error "something went wrong while installing official packages!"
}
