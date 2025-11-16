#!/usr/bin/env bash

# Source required utilities
VIRT_MANAGER_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${VIRT_MANAGER_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure virt-manager and qemu
configure_virt_manager() {
    log "Configuring virt-manager and qemu..."
    
    sed -i 's|#unix_sock_group|unix_sock_group|' /mnt/etc/libvirt/libvirtd.conf
    sed -i 's|#unix_sock_rw_perms|unix_sock_rw_perms|' /mnt/etc/libvirt/libvirtd.conf
    sed -i "/#user =/c user = \"${NEW_USER}\"" /mnt/etc/libvirt/qemu.conf
    sed -i "/#group =/c group = \"wheel\"" /mnt/etc/libvirt/qemu.conf
    
    log "Virt-manager and qemu configured successfully"
}