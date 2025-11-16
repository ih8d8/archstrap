#!/usr/bin/env bash

# Source required utilities
LUKS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LUKS_SCRIPT_DIR}/../utils/logging.sh"
fi

# Source formatting utilities
source "${LUKS_SCRIPT_DIR}/filesystem.sh"
# Source mount utilities for get_mount_options function
source "${LUKS_SCRIPT_DIR}/mount.sh"

# Setup LUKS encryption (automated)
setup_luks_automated() {
    log "Setting up LUKS encryption..."
    
    # Create LUKS partition using stored password
    echo -n "${LUKS_PASSWORD}" | cryptsetup luksFormat -q "${LUKS_PARTITION}" -
    
    # Open LUKS partition
    log "Opening LUKS partition..."
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${LUKS_PARTITION}" luks -
    export LUKS_OPENED=true
    export CLEANUP_NEEDED=true
    
    # Get LUKS UUID for later use - declare and assign separately
    local luks_uuid
    luks_uuid=$(blkid -s UUID -o value "${LUKS_PARTITION}")
    export LUKS_UUID="${luks_uuid}"
    log "LUKS UUID: ${LUKS_UUID}"
}

setup_secondary_luks_auto_unlock() {
    # Setup LUKS encryption on a secondary disk that will be decrypted automatically after decrypting the primary disk
    echo "=== LUKS Auto-Unlock Setup ==="
    echo
    
    # Check if secondary device was selected during input collection
    if [[ -z "${SECONDARY_BLOCK_DEVICE:-}" ]]; then
        log "No secondary block device configured. Skipping secondary LUKS setup."
        return 0
    fi
    
    local target_disk="${SECONDARY_BLOCK_DEVICE}"
    local mapper_name="luks2"
    log "Setting up secondary LUKS encryption on: ${target_disk}"
    
    # Verify target disk exists
    if [[ ! -b "$target_disk" ]]; then
        log "ERROR: Secondary block device $target_disk does not exist"
        return 1
    fi
    
    # Clean up any existing LUKS mappings for the secondary device
    log "Cleaning up any existing LUKS mappings for secondary device..."
    
    # Close any existing mapper if it exists
    if dmsetup info "$mapper_name" >/dev/null 2>&1; then
        log "Closing existing LUKS mapping: $mapper_name"
        cryptsetup close "$mapper_name" 2>/dev/null || {
            warning "Failed to close existing mapping normally, trying force removal..."
            dmsetup remove --force "$mapper_name" 2>/dev/null || {
                dmsetup suspend "$mapper_name" 2>/dev/null || true
                dmsetup remove "$mapper_name" 2>/dev/null || true
            }
        }
    fi
    
    # Try to wipe filesystem signatures, but don't fail if it doesn't work
    log "Wiping filesystem signatures and partition table on $target_disk..."
    if ! wipefs -a "$target_disk" 2>/dev/null; then
        warning "Failed to wipe existing file systems on $target_disk, continuing anyway..."
        # Try alternative cleanup methods
        log "Attempting to clear device using dd..."
        dd if=/dev/zero of="$target_disk" bs=1M count=100 2>/dev/null || {
            warning "dd cleanup also failed, continuing with LUKS setup..."
        }
    else
        log "Successfully wiped existing file systems"
    fi
    
    # Generate keyfile for secondary LUKS partition
    local keyfile="/mnt/root/luks2.key"
    echo "Generating keyfile at $keyfile..."
    if ! dd if=/dev/urandom of="$keyfile" bs=4096 count=1; then
        log "ERROR: Failed to generate keyfile"
        return 1
    fi
    
    if ! chmod 600 "$keyfile"; then
        log "ERROR: Failed to set keyfile permissions"
        return 1
    fi
    
    # Setup LUKS
    echo "Setting up LUKS partition..."
    if ! cryptsetup luksFormat -q "$target_disk" "$keyfile"; then
        log "ERROR: Failed to format LUKS partition on $target_disk"
        return 1
    fi
    
    # Get UUID - declare and assign separately
    local uuid
    if ! uuid=$(cryptsetup luksUUID "$target_disk"); then
        log "ERROR: Failed to get LUKS UUID for $target_disk"
        return 1
    fi
    
    # Open and format
    echo "Opening LUKS partition..."
    if ! cryptsetup open "$target_disk" "$mapper_name" --key-file="$keyfile"; then
        log "ERROR: Failed to open LUKS partition $target_disk"
        return 1
    fi
    
    # Set flag to track secondary LUKS state for cleanup
    export SECONDARY_LUKS_OPENED=true
    
    echo "Creating ${FILESYSTEM_FORMAT:-ext4} filesystem..."
    if ! format_secondary_partition "/dev/mapper/$mapper_name"; then
        log "ERROR: Failed to create ${FILESYSTEM_FORMAT:-ext4} filesystem on /dev/mapper/$mapper_name"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    # Get the filesystem UUID (different from LUKS UUID) - declare and assign separately
    local fs_uuid
    if ! fs_uuid=$(blkid -s UUID -o value "/dev/mapper/$mapper_name"); then
        log "ERROR: Failed to get filesystem UUID for /dev/mapper/$mapper_name"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    # Add to crypttab
    echo "Adding to /etc/crypttab..."
    # Use path as it will be seen from within the installed system
    local crypttab_keyfile="/root/luks2.key"
    if ! echo "$mapper_name UUID=$uuid $crypttab_keyfile luks" >> /mnt/etc/crypttab; then
        log "ERROR: Failed to add entry to /etc/crypttab"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    # Create mount point and add to fstab
    local mount_point="/mnt/Data"
    local in_iso_mount_point="/mnt/mnt/Data"
    if ! mkdir -p "$in_iso_mount_point"; then
        log "ERROR: Failed to create mount point $in_iso_mount_point"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    # Set ownership permissions - defer to post-install when user exists
    log "Setting basic permissions for $in_iso_mount_point (user ownership will be set post-install)"
    if ! chmod 755 "$in_iso_mount_point"; then
        log "ERROR: Failed to set permissions for $in_iso_mount_point"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    echo "Adding to /etc/fstab..."
    local mount_options
    mount_options=$(get_mount_options)
    if ! echo "UUID=$fs_uuid $mount_point ${FILESYSTEM_FORMAT:-ext4} ${mount_options},nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=Data 0 2" >> /mnt/etc/fstab; then
        log "ERROR: Failed to add entry to /etc/fstab"
        cryptsetup close "$mapper_name"
        return 1
    fi
    
    # Close the mapper (it will be opened automatically on boot)
    if ! cryptsetup close "$mapper_name"; then
        log "WARNING: Failed to close LUKS mapper $mapper_name"
        # Don't fail here as the setup was successful
    else
        export SECONDARY_LUKS_OPENED=false
    fi
    
    echo
    echo "=== Setup Complete ==="
    echo "Device: $target_disk"
    echo "Mapper: /dev/mapper/$mapper_name"
    echo "Mount point: $mount_point"
    echo "Keyfile: $keyfile"
    echo
    echo "The partition will auto-unlock on boot after you unlock your main disk."
    echo "You can mount it now with: mount $mount_point"
    
    log "Secondary LUKS setup completed successfully"
    return 0
}