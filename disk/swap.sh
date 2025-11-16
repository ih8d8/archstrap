#!/usr/bin/env bash

# Source required utilities
SWAP_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SWAP_SCRIPT_DIR}/../utils/logging.sh"
fi

# Create swap file
create_swapfile() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    log "Creating swap file for ${filesystem}..."
    
    if [[ "${filesystem}" == "btrfs" ]]; then
        # For Btrfs, use the dedicated mkswapfile command
        # The @swap subvolume should already be mounted at /mnt/swap
        log "Creating Btrfs swapfile using btrfs filesystem mkswapfile..."
        
        # Create 4GB swapfile using btrfs mkswapfile (handles NOCOW and pre-allocation automatically)
        if ! btrfs filesystem mkswapfile --size 4g --uuid clear /mnt/swap/swapfile; then
            fatal_error "Failed to create Btrfs swapfile"
        fi
    else
        # For ext4 and other filesystems
        mkdir -p /mnt/swap
        dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=4096 status=progress
        chmod 600 /mnt/swap/swapfile
        mkswap /mnt/swap/swapfile
    fi
    
    # Add fstab entry
    echo '/swap/swapfile none swap defaults 0 0' >> /mnt/etc/fstab
}