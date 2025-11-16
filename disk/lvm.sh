#!/usr/bin/env bash

# Source required utilities
LVM_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LVM_SCRIPT_DIR}/../utils/logging.sh"
fi

# Setup LVM
setup_lvm() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    if [[ "${filesystem}" == "btrfs" ]]; then
        log "Skipping LVM setup for btrfs filesystem - using direct formatting"
        export LVM_CREATED=false
        return 0
    fi
    
    log "Setting up LVM..."
    
    # Wait for the LUKS device to be fully available
    log "Waiting for LUKS device /dev/mapper/luks to be ready..."
    udevadm settle
    sleep 2 # Additional small delay for good measure

    # Create physical volume
    pvcreate /dev/mapper/luks || fatal_error "Failed to create physical volume on /dev/mapper/luks"
    
    # Create volume group
    vgcreate vg1 /dev/mapper/luks
    
    # Create logical volumes
    lvcreate -l 40%FREE vg1 -n root       # 40% of free space
    lvcreate -l 100%FREE vg1 -n home      # 100% of the remaining free space
    
    export LVM_CREATED=true
    
    log "LVM setup completed successfully"
}