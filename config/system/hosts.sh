#!/usr/bin/env bash

# Source required utilities
HOSTS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${HOSTS_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure hosts file
configure_hosts() {
    log "Configuring hosts file..."
    
    # Written, not appended: the base install already ships an /etc/hosts with
    # the two localhost lines, so appending produced a second copy of each.
    cat <<EOF >/mnt/etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.
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