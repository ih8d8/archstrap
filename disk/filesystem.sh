#!/usr/bin/env bash

# Source required utilities
FORMAT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${FORMAT_SCRIPT_DIR}/../utils/logging.sh"
fi

# Format logical volumes based on selected filesystem
format_logical_volumes() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    log "Formatting logical volumes with ${filesystem}..."
    
    case "${filesystem}" in
        "ext4")
            format_ext4_volumes
            ;;
        "btrfs")
            if [[ "${LVM_CREATED:-false}" == "true" ]]; then
                format_btrfs_volumes
            else
                format_btrfs_direct
            fi
            ;;
        *)
            fatal_error "Unsupported filesystem format: ${filesystem}"
            ;;
    esac
}

# Format logical volumes with ext4
format_ext4_volumes() {
    log "Formatting logical volumes with ext4..."
    
    # Format root volume with ext4
    if ! mkfs.ext4 -m 1 /dev/vg1/root; then
        fatal_error "Failed to format root volume with ext4"
    fi
    
    # Format home volume with ext4
    if ! mkfs.ext4 -m 1 /dev/vg1/home; then
        fatal_error "Failed to format home volume with ext4"
    fi
    
    log "ext4 formatting completed successfully"
}

# Format logical volumes with btrfs
format_btrfs_volumes() {
    log "Formatting logical volumes with btrfs..."
    
    # Format root volume with btrfs
    if ! mkfs.btrfs -f /dev/vg1/root; then
        fatal_error "Failed to format root volume with btrfs"
    fi
    
    # Format home volume with btrfs
    if ! mkfs.btrfs -f /dev/vg1/home; then
        fatal_error "Failed to format home volume with btrfs"
    fi
    
    log "btrfs formatting completed successfully"
}

# Format LUKS device directly with btrfs (no LVM)
format_btrfs_direct() {
    log "Formatting LUKS device directly with btrfs..."
    
    # Format the LUKS device directly with btrfs
    if ! mkfs.btrfs -f -L archlinux /dev/mapper/luks; then
        fatal_error "Failed to format LUKS device with btrfs"
        return 1
    fi
    
    log "Direct btrfs formatting completed successfully"
}

# Format secondary LUKS partition
format_secondary_partition() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    local device="${1:-/dev/mapper/luks2}"
    
    if [[ ! -b "${device}" ]]; then
        log "Secondary device ${device} not found, skipping format"
        return 0
    fi
    
    log "Formatting secondary partition ${device} with ${filesystem}..."
    
    case "${filesystem}" in
        "ext4")
            if ! mkfs.ext4 -m 1 -L secondary "${device}"; then
                fatal_error "Failed to format secondary partition with ext4"
            fi
            ;;
        "btrfs")
            if ! mkfs.btrfs -f -L secondary "${device}"; then
                fatal_error "Failed to format secondary partition with btrfs"
            fi
            ;;
        *)
            fatal_error "Unsupported filesystem format: ${filesystem}"
            ;;
    esac
    
    log "Secondary partition formatting completed successfully"
}

# Create btrfs subvolumes if using btrfs
create_btrfs_subvolumes() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    if [[ "${filesystem}" != "btrfs" ]]; then
        return 0
    fi
    
    log "Creating btrfs subvolumes..."
    
    # Determine the device to mount based on LVM usage
    local btrfs_device
    if [[ "${LVM_CREATED:-false}" == "true" ]]; then
        btrfs_device="/dev/vg1/root"
    else
        btrfs_device="/dev/mapper/luks"
    fi
    
    # Mount volume temporarily to create subvolumes
    mkdir -p /mnt/btrfs-root
    mount "${btrfs_device}" /mnt/btrfs-root
    
    # Create subvolumes on root volume (excluding @snapshots - snapper will create it)
    btrfs subvolume create /mnt/btrfs-root/@
    btrfs subvolume create /mnt/btrfs-root/@var
    btrfs subvolume create /mnt/btrfs-root/@tmp
    btrfs subvolume create /mnt/btrfs-root/@swap
    
    # Create subvolumes on home volume if it exists (only when using LVM)
    if [[ "${LVM_CREATED:-false}" == "true" && -b /dev/vg1/home ]]; then
        log "Creating subvolumes on home volume..."
        mkdir -p /mnt/btrfs-home
        mount /dev/vg1/home /mnt/btrfs-home
        
        # Create @home subvolume and separate snapshots subvolume on home volume
        btrfs subvolume create /mnt/btrfs-home/@home
        btrfs subvolume create /mnt/btrfs-home/@home_snapshots
        
        # Unmount temporary mount
        umount /mnt/btrfs-home
        rmdir /mnt/btrfs-home
        
        log "Home volume subvolumes created successfully"
    elif [[ "${LVM_CREATED:-false}" == "false" ]]; then
        # When not using LVM, create @home subvolume in main btrfs volume
        log "Creating @home subvolume in main btrfs volume..."
        btrfs subvolume create /mnt/btrfs-root/@home
        log "Home subvolume created in main btrfs volume"
    fi
    
    # Unmount temporary mount
    umount /mnt/btrfs-root
    rmdir /mnt/btrfs-root
    
    log "btrfs subvolumes created successfully"
}

