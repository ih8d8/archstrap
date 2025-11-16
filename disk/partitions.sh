#!/usr/bin/env bash

# Source required utilities
PARTITIONS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${PARTITIONS_SCRIPT_DIR}/../utils/logging.sh"
fi

# Create partitions
create_partitions() {
    log "Creating partitions on ${BLOCK_DEVICE}..."
    
    # Verify the block device exists
    if [[ ! -b "${BLOCK_DEVICE}" ]]; then
        fatal_error "Block device ${BLOCK_DEVICE} does not exist or is not accessible"
    fi
    
    # Check for existing file systems and wipe them
    if blkid "${BLOCK_DEVICE}" >/dev/null 2>&1; then
        log "Existing file systems detected on ${BLOCK_DEVICE}. Cleaning up and wiping..."
        cleanup 0 true # Force cleanup before wiping
        
        # Try to wipe filesystem signatures, but don't fail if it doesn't work
        if ! wipefs -a "${BLOCK_DEVICE}" 2>/dev/null; then
            warning "Failed to wipe existing file systems on ${BLOCK_DEVICE}, continuing anyway..."
            # Try alternative cleanup methods
            log "Attempting to clear device using dd..."
            dd if=/dev/zero of="${BLOCK_DEVICE}" bs=1M count=100 2>/dev/null || {
                warning "dd cleanup also failed, continuing with partition creation..."
            }
        else
            log "Successfully wiped existing file systems"
        fi
    fi

    # Clear existing partitions and create new ones
    log "Creating new partition table and partitions..."
    if ! sgdisk --clear \
                -n 1:0:+2G -t 1:ef00 \
                -n 2:0:0 -t 2:8e00 \
                "${BLOCK_DEVICE}"; then
        fatal_error "Failed to create partitions on ${BLOCK_DEVICE}"
    fi
    
    # Wait for partition table to be re-read
    log "Waiting for partition table to be re-read..."
    sleep 2
    partprobe "${BLOCK_DEVICE}" 2>/dev/null || true
    sleep 2
    
    # Verify partitions were created
    if ! lsblk "${BLOCK_DEVICE}" | grep -q part; then
        fatal_error "Partition creation verification failed - no partitions found on ${BLOCK_DEVICE}"
    fi
    
    log "Partitions created successfully"
    lsblk "${BLOCK_DEVICE}"
    export CLEANUP_NEEDED=true
}

# Auto-detect partition paths
detect_partitions() {
    log "Auto-detecting partition paths..."
    
    # Determine partition naming scheme
    if [[ "${BLOCK_DEVICE}" == *"nvme"* ]]; then
        BOOT_PARTITION="${BLOCK_DEVICE}p1"
        LUKS_PARTITION="${BLOCK_DEVICE}p2"
    else
        BOOT_PARTITION="${BLOCK_DEVICE}1"
        LUKS_PARTITION="${BLOCK_DEVICE}2"
    fi
    
    # Verify partitions exist
    if [[ ! -b "${BOOT_PARTITION}" ]] || [[ ! -b "${LUKS_PARTITION}" ]]; then
        fatal_error "Could not detect partitions. Boot: ${BOOT_PARTITION}, LUKS: ${LUKS_PARTITION}"
    fi
    
    log "Boot partition: ${BOOT_PARTITION}"
    log "LUKS partition: ${LUKS_PARTITION}"
}

# Format EFI partition
format_efi_partition() {
    log "Formatting EFI partition..."
    mkfs.fat -F32 "${BOOT_PARTITION}"
}