#!/usr/bin/env bash

# Source required utilities
ROOT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${ROOT_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Set root password with proper error handling
set_root_password() {
    log "Setting root password..."
    
    # Validate required variables
    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
        fatal_error "ROOT_PASSWORD variable is not set"
    fi
    
    # Set root password using piped input with error checking
    if echo "root:${ROOT_PASSWORD}" | arch-chroot /mnt chpasswd; then
        log "Root password set successfully"
        return 0
    else
        fatal_error "Failed to set root password"
    fi
}