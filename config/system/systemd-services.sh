#!/usr/bin/env bash

# Source required utilities
SYSTEMD_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SYSTEMD_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Enable required services
enable_services() {
    log "Enabling required services..."
    
    local SERVICES="sddm.service fstrim.timer haveged.service cronie.service vnstat.service atd.service tlp.service
thermald.service cpupower.service libvirtd.service dnscrypt-proxy.service resolvconf-dnscrypt-proxy.service
bluetooth.service cups.service tailscaled.service ufw.service"

    for SERVICE in ${SERVICES}; do
        arch-chroot /mnt systemctl enable "${SERVICE}" || warning "Failed to enable ${SERVICE}"
    done
    
    # Enable btrfs-specific services if using btrfs filesystem
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    if [[ "${filesystem}" == "btrfs" ]]; then
        log "Enabling btrfs-specific services..."
        arch-chroot /mnt systemctl enable "refind-btrfs-snapshots.path" || warning "Failed to enable refind-btrfs-snapshots.path"
    fi
    
    log "Required services enabled successfully"
    return 0
}

# Disable unwanted services
disable_services() {
    log "Disabling unwanted services..."
    
    local SERVICES="NetworkManager-wait-online.service systemd-resolved.service"
    
    for SERVICE in ${SERVICES}; do
        arch-chroot /mnt systemctl disable "${SERVICE}" || warning "Failed to disable ${SERVICE}"
    done
    
    log "Unwanted services disabled successfully"
    return 0
}