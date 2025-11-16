#!/usr/bin/env bash

# Source required utilities
HOSTS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${HOSTS_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure hosts file
configure_hosts() {
    log "Configuring hosts file..."
    
    cat <<EOF >>/mnt/etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    ${HOSTNAME}
EOF
    
    log "Hosts file configured successfully"
}

# Configure hostname
configure_hostname() {
    log "Configuring hostname..."
    
    echo "${HOSTNAME}" > /mnt/etc/hostname
    
    log "Hostname configured successfully"
}