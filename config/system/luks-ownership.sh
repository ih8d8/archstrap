#!/usr/bin/env bash

# Source required utilities
LUKS_OWNERSHIP_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LUKS_OWNERSHIP_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Set ownership for secondary LUKS mount point after user creation with proper error handling
set_secondary_luks_ownership() {
    local mount_point="/mnt/Data"
    local in_iso_mount_point="/mnt/mnt/Data"

    # Validate NEW_USER variable
    if [[ -z "${NEW_USER:-}" ]]; then
        error "NEW_USER variable is not set or empty"
        return 1
    fi
    
    if [[ -d "$in_iso_mount_point" ]]; then
        log "Setting ownership for secondary LUKS partition: $mount_point"
        
        local mapper_name="luks2"
        local keyfile="/root/luks2.key"
        local mapper_device="/dev/mapper/$mapper_name"
        
        # Check if keyfile exists in chroot
        if ! arch-chroot /mnt test -f "$keyfile"; then
            error "LUKS keyfile $keyfile not found in chroot environment"
            return 1
        fi
        
        # Open the LUKS container if not already open
        log "Opening LUKS container $mapper_name..."
        if ! arch-chroot /mnt cryptsetup status "$mapper_name" >/dev/null 2>&1; then
            # Find the LUKS device UUID from crypttab
            local luks_uuid
            luks_uuid=$(arch-chroot /mnt grep "^$mapper_name" /etc/crypttab | awk '{print $2}' | sed 's/UUID=//')
            if [[ -z "$luks_uuid" ]]; then
                error "Could not find LUKS UUID for $mapper_name in /etc/crypttab"
                return 1
            fi
            
            # Find the device by UUID
            local luks_device
            luks_device=$(arch-chroot /mnt blkid -U "$luks_uuid")
            if [[ -z "$luks_device" ]]; then
                error "Could not find LUKS device with UUID $luks_uuid"
                return 1
            fi
            
            log "Opening LUKS device $luks_device as $mapper_name..."
            if ! arch-chroot /mnt cryptsetup open "$luks_device" "$mapper_name" --key-file="$keyfile"; then
                error "Failed to open LUKS device $luks_device"
                return 1
            fi
            local luks_opened=true
        else
            log "LUKS container $mapper_name is already open"
            local luks_opened=false
        fi
        
        # Mount the secondary LUKS partition inside chroot
        log "Mounting secondary LUKS partition from $mapper_device to $mount_point..."
        if ! arch-chroot /mnt mount "$mapper_device" "$mount_point"; then
            error "Failed to mount $mapper_device to $mount_point"
            if [[ "$luks_opened" == "true" ]]; then
                arch-chroot /mnt cryptsetup close "$mapper_name" 2>/dev/null || true
            fi
            return 1
        fi
        
        # Set ownership on the mounted filesystem
        log "Setting ownership of mounted filesystem to ${NEW_USER}:wheel"
        if arch-chroot /mnt chown "${NEW_USER}":wheel "$mount_point"; then
            log "Successfully set ownership of mounted $mount_point to ${NEW_USER}:wheel"
        else
            error "Failed to set ownership of mounted $mount_point to ${NEW_USER}:wheel"
            # Cleanup: unmount and close LUKS if we opened it
            arch-chroot /mnt umount "$mount_point" 2>/dev/null || true
            if [[ "$luks_opened" == "true" ]]; then
                arch-chroot /mnt cryptsetup close "$mapper_name" 2>/dev/null || true
            fi
            return 1
        fi
        
        # Unmount the partition
        log "Unmounting secondary LUKS partition..."
        if ! arch-chroot /mnt umount "$mount_point"; then
            error "Failed to unmount $mount_point"
            if [[ "$luks_opened" == "true" ]]; then
                arch-chroot /mnt cryptsetup close "$mapper_name" 2>/dev/null || true
            fi
            return 1
        fi
        
        # Close LUKS container if we opened it
        if [[ "$luks_opened" == "true" ]]; then
            log "Closing LUKS container $mapper_name..."
            if ! arch-chroot /mnt cryptsetup close "$mapper_name"; then
                warning "Failed to close LUKS container $mapper_name"
            else
                log "Successfully closed LUKS container $mapper_name"
            fi
        fi
        
        log "Successfully set ownership for secondary LUKS partition"
        return 0
    else
        log "Secondary LUKS mount point $mount_point does not exist, skipping ownership setting"
        return 0
    fi
}