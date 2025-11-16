#!/usr/bin/env bash

# Source required utilities
FSTAB_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${FSTAB_SCRIPT_DIR}/../utils/logging.sh"
fi

# Generate fstab
generate_fstab() {
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Add root snapshots subvolume to fstab for btrfs (snapper does not automatically add it)
    add_root_snapshots_to_fstab
}

# Add root snapshots subvolume to fstab (positioned after root subvolume entry)
add_root_snapshots_to_fstab() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    if [[ "${filesystem}" != "btrfs" ]]; then
        return 0
    fi
    
    log "Adding root snapshots subvolume to fstab..."
    
    # Find the line with the root subvolume and add snapshots entry after it
    local root_device
    if [[ "${LVM_CREATED:-true}" == "true" ]]; then
        root_device="/dev/vg1/root"
    else
        root_device="/dev/mapper/luks"
    fi
    
    local root_uuid=$(blkid -s UUID -o value "${root_device}")
    local snapshots_entry="UUID=${root_uuid}       /.snapshots     btrfs           rw,relatime,compress=zstd:3,space_cache=v2,subvol=@/.snapshots    0 0"
    
    # Add snapshots entry only after the root filesystem line (/) - make pattern specific
    local device_comment
    if [[ "${LVM_CREATED:-true}" == "true" ]]; then
        device_comment="# /dev/mapper/vg1-root"
    else
        device_comment="# /dev/mapper/luks"
    fi
    
    sed -i "/UUID=${root_uuid}.*\/[[:space:]].*subvol=\/@/a\\\\n${device_comment}\\n${snapshots_entry}" /mnt/etc/fstab
    
    log "Root snapshots fstab entry added successfully"
}