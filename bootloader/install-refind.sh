#!/usr/bin/env bash

REFIND_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${REFIND_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install and configure refind
install_refind() {
    log "Installing and configuring rEFInd..."
    
    arch-chroot /mnt refind-install
    
    log "rEFInd installed successfully"
}
