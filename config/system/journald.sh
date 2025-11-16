#!/usr/bin/env bash

# Source required utilities
JOURNALD_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${JOURNALD_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure journal log size
configure_journald() {
    log "Configuring journal log size..."
    
    sed -i 's|#SystemMaxUse=|SystemMaxUse=100M|' /mnt/etc/systemd/journald.conf
    
    log "Journald configured successfully"
}