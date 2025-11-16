#!/usr/bin/env bash

# Source required utilities
MOUNT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${MOUNT_SCRIPT_DIR}/../utils/logging.sh"
fi

# Source formatting utilities
source "${MOUNT_SCRIPT_DIR}/filesystem.sh"

# Get mount options based on filesystem type
get_mount_options() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    case "${filesystem}" in
        "ext4")
            echo "defaults,relatime"
            ;;
        "btrfs")
            echo "defaults,relatime,compress=zstd"
            ;;
        *)
            echo "defaults"
            ;;
    esac
}

# Mount filesystems with appropriate options
mount_formatted_filesystems() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    local mount_options
    mount_options=$(get_mount_options)
    
    log "Mounting filesystems with ${filesystem} and options: ${mount_options}..."
    
    if [[ "${filesystem}" == "btrfs" ]]; then
        if [[ "${LVM_CREATED:-false}" == "true" ]]; then
            # Mount btrfs subvolumes from LVM
            mount -o "${mount_options},subvol=@" /dev/vg1/root /mnt
            
            # Create mount points (excluding .snapshots - snapper will handle it)
            mkdir -p /mnt/{home,var,tmp,swap}
            
            # Mount other subvolumes (excluding @snapshots - snapper will handle it)
            mount -o "${mount_options},subvol=@var" /dev/vg1/root /mnt/var
            mount -o "${mount_options},subvol=@tmp" /dev/vg1/root /mnt/tmp
            mount -o "${mount_options},subvol=@swap" /dev/vg1/root /mnt/swap
            
            # Mount @home subvolume from separate home LVM volume
            if [[ -b /dev/vg1/home ]]; then
                mount -o "${mount_options},subvol=@home" /dev/vg1/home /mnt/home
                
                # Create and mount home snapshots directory
                mkdir -p /mnt/home/.snapshots
                mount -o "${mount_options},subvol=@home_snapshots" /dev/vg1/home /mnt/home/.snapshots
            fi
        else
            # Mount btrfs subvolumes directly from LUKS device
            mount -o "${mount_options},subvol=@" /dev/mapper/luks /mnt
            
            # Create mount points
            mkdir -p /mnt/{home,var,tmp,swap}
            
            # Mount other subvolumes from the same device
            mount -o "${mount_options},subvol=@home" /dev/mapper/luks /mnt/home
            mount -o "${mount_options},subvol=@var" /dev/mapper/luks /mnt/var
            mount -o "${mount_options},subvol=@tmp" /dev/mapper/luks /mnt/tmp
            mount -o "${mount_options},subvol=@swap" /dev/mapper/luks /mnt/swap
        fi
    else
        # Mount ext4 filesystems normally
        mount -o "${mount_options}" /dev/vg1/root /mnt
        mkdir -p /mnt/{home,swap}
        mount -o "${mount_options}" /dev/vg1/home /mnt/home
    fi
    
    log "Filesystems mounted successfully"
}

# Mount filesystems
mount_filesystems() {
    log "Mounting filesystems..."
    
    # Mount filesystems with appropriate options based on filesystem type
    mount_formatted_filesystems
    
    # Create and mount boot directory
    mkdir -p /mnt/boot
    mount "${BOOT_PARTITION}" /mnt/boot
    
    export FILESYSTEMS_MOUNTED=true
    
    log "Filesystems mounted:"
    lsblk
}