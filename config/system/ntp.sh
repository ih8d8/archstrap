#!/usr/bin/env bash

# Source required utilities
NTP_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${NTP_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Update system clock in ISO environment (live USB)
update_iso_system_clock() {
    log "Updating system clock in ISO environment..."
    timedatectl set-ntp true
    log "System clock synchronized in ISO environment"
}

# Update system clock in installed system
update_installed_system_clock() {
    log "Updating system clock in installed system..."
    arch-chroot /mnt timedatectl set-ntp true
    log "System clock synchronized in installed system"
}