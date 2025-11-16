#!/usr/bin/env bash

# Source required utilities
NANO_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${NANO_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure nano
configure_nano() {
    log "Configuring nano..."
    
    sed -i 's|# include "/usr/share/nano/\*.nanorc"|include "/usr/share/nano/*.nanorc"|' /mnt/etc/nanorc
    
    log "Nano configured successfully"
}