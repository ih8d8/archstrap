#!/usr/bin/env bash

# Source required utilities
BASE_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${BASE_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install base system
install_base_system() {
    log "Installing base system..."
    
    pacstrap -K /mnt base base-devel linux linux-headers linux-lts linux-lts-headers \
             linux-firmware lvm2 vim git networkmanager refind os-prober efibootmgr \
             iwd intel-ucode curl reflector --noconfirm --ask=4
}
