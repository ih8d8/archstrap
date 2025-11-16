#!/usr/bin/env bash

# Source required utilities
GVFS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${GVFS_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure gvfs-mtp
configure_gvfs() {
    log "Configuring gvfs-mtp..."
    
    sed -i 's|AutoMount=false|AutoMount=true|' /mnt/usr/share/gvfs/mounts/mtp.mount
    
    log "GVFS configured successfully"
}