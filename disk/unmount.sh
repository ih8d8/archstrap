#!/usr/bin/env bash

# Source required utilities
UNMOUNT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${UNMOUNT_SCRIPT_DIR}/../utils/logging.sh"
fi

# Unmount filesystems safely
unmount_filesystems() {
    log "Unmounting filesystems..."
    
    # Unmount in reverse order with fallback to lazy unmount
    log "Unmounting /mnt/home..."
    umount /mnt/home 2>/dev/null || {
        warning "Failed to unmount /mnt/home, trying lazy unmount..."
        umount -l /mnt/home 2>/dev/null || warning "Lazy unmount of /mnt/home also failed"
    }
    
    log "Unmounting /mnt/boot..."
    umount /mnt/boot 2>/dev/null || {
        warning "Failed to unmount /mnt/boot, trying lazy unmount..."
        umount -l /mnt/boot 2>/dev/null || warning "Lazy unmount of /mnt/boot also failed"
    }
    
    log "Unmounting /mnt..."
    umount /mnt 2>/dev/null || {
        warning "Failed to unmount /mnt, trying lazy unmount..."
        umount -l /mnt 2>/dev/null || warning "Lazy unmount of /mnt also failed"
    }
    
    sleep 2
    export FILESYSTEMS_MOUNTED=false
}