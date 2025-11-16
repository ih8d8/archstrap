#!/usr/bin/env bash

# Source required utilities
MKINITCPIO_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${MKINITCPIO_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure mkinitcpio for LUKS and LVM
configure_mkinitcpio() {
    log "Configuring mkinitcpio ..."
    
    # Check if using systemd hooks and configure accordingly
    if grep -q '^HOOKS=.*systemd' /mnt/etc/mkinitcpio.conf; then
        log "Detected systemd hooks, using sd-encrypt for systemd-based encryption..."
        sed -i '/^HOOKS/s/\(block \)\(.*filesystems\)/\1sd-encrypt \2/' /mnt/etc/mkinitcpio.conf
    else
        log "Using traditional hooks, adding encrypt hook..."
        # Add encrypt hook after block
        sed -i '/^HOOKS/s/\(block \)\(.*filesystems\)/\1encrypt \2/' /mnt/etc/mkinitcpio.conf
    fi
    
    # Create /etc/vconsole.conf to prevent error
    if [[ ! -f /mnt/etc/vconsole.conf ]]; then
        log "Creating /etc/vconsole.conf..."
        echo 'KEYMAP=us' > /mnt/etc/vconsole.conf
    fi
    
    # Add lvm2 hook only if using ext4 filesystem (LVM setup)
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    if [[ "${filesystem}" == "ext4" ]]; then
        log "Adding lvm2 hook for LVM support..."
        sed -i '/^HOOKS/s/\(encrypt \)\(.*filesystems\)/\1lvm2 \2/' /mnt/etc/mkinitcpio.conf
    fi
    
    # Add btrfs module if using btrfs filesystem
    if [[ "${filesystem}" == "btrfs" ]]; then
        log "Adding btrfs module for btrfs filesystem support..."
        sed -i '/^MODULES=/s/()/(btrfs)/' /mnt/etc/mkinitcpio.conf
    fi
    
    # Generate initramfs
    arch-chroot /mnt mkinitcpio -p linux
    arch-chroot /mnt mkinitcpio -p linux-lts
    
    log "Mkinitcpio configured successfully"
}