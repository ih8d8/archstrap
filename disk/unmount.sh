#!/usr/bin/env bash

# Source required utilities
UNMOUNT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${UNMOUNT_SCRIPT_DIR}/../utils/logging.sh"
fi

# Source filesystem utilities to get filesystem type
source "${UNMOUNT_SCRIPT_DIR}/filesystem.sh"

# Safe unmount function with fallback to lazy unmount
safe_umount() {
    local mount_point="$1"
    local description="${2:-$mount_point}"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log "Unmounting $description..."
        umount "$mount_point" 2>/dev/null || {
            warning "Failed to unmount $description, trying lazy unmount..."
            umount -l "$mount_point" 2>/dev/null || warning "Lazy unmount of $description also failed"
        }
    else
        log "$description is not mounted, skipping..."
    fi
}

# Unmount btrfs filesystems with subvolumes
unmount_btrfs_filesystems() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    log "Unmounting btrfs filesystems..."
    
    # Unmount btrfs subvolumes in reverse order of mounting
    if [[ "${LVM_CREATED:-false}" == "true" ]]; then
        # When using LVM with separate home volume
        safe_umount "/mnt/home/.snapshots" "home snapshots subvolume"
        safe_umount "/mnt/home" "home subvolume"
        safe_umount "/mnt/swap" "swap subvolume" 
        safe_umount "/mnt/tmp" "tmp subvolume"
        safe_umount "/mnt/var" "var subvolume"
    else
        # When using direct LUKS device (all subvolumes on same device)
        safe_umount "/mnt/swap" "swap subvolume"
        safe_umount "/mnt/tmp" "tmp subvolume"
        safe_umount "/mnt/var" "var subvolume"
        safe_umount "/mnt/home" "home subvolume"
    fi
    
    safe_umount "/mnt/boot" "boot partition"
    safe_umount "/mnt" "root subvolume"
}

# Unmount ext4 filesystems
unmount_ext4_filesystems() {
    log "Unmounting ext4 filesystems..."
    
    # Unmount in reverse order
    safe_umount "/mnt/home" "home partition"
    safe_umount "/mnt/boot" "boot partition" 
    safe_umount "/mnt" "root partition"
}

# Unmount filesystems safely based on filesystem type
unmount_filesystems() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    log "Unmounting filesystems (filesystem: $filesystem)..."
    
    case "${filesystem}" in
        "btrfs")
            unmount_btrfs_filesystems
            ;;
        "ext4")
            unmount_ext4_filesystems
            ;;
        *)
            warning "Unknown filesystem type: $filesystem, falling back to generic unmount..."
            unmount_ext4_filesystems
            ;;
    esac
    
    sleep 2
    export FILESYSTEMS_MOUNTED=false
    log "Filesystem unmounting completed"
}