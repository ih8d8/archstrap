#!/usr/bin/env bash

# Source required utilities
VI_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${VI_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure vi symlink
configure_vi() {
    log "Configuring vi symlink..."
    
    arch-chroot /mnt ln -sf /usr/bin/nvim /usr/bin/vi
    
    log "Vi symlink configured successfully"
}