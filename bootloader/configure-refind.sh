#!/usr/bin/env bash

# Source required utilities
REFIND_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${REFIND_SCRIPT_DIR}/../utils/logging.sh"
fi

# Configure refind bootloader
configure_refind() {
    log "Configuring rEFInd bootloader..."
    
    # Prepare boot options with proper root device based on LVM usage
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    local root_device
    
    # Determine root device based on LVM usage
    if [[ "${LVM_CREATED:-true}" == "true" ]]; then
        root_device="/dev/vg1/root"
    else
        root_device="/dev/mapper/luks"
    fi
    
    # Configure boot parameters based on encryption type
    local blk_options
    if grep -q '^HOOKS=.*systemd' /mnt/etc/mkinitcpio.conf; then
        log "Using systemd-style boot parameters for sd-encrypt..."
        # For systemd hooks, use rd.luks parameters
        blk_options="rd.luks.name=${LUKS_UUID}=luks root=${root_device}"
    else
        log "Using traditional boot parameters for encrypt hook..."
        # For traditional hooks, use cryptdevice parameter
        blk_options="cryptdevice=UUID=${LUKS_UUID}:luks root=${root_device}"
    fi
    
    # Add rootflags for Btrfs subvolume if using Btrfs
    if [[ "${filesystem}" == "btrfs" ]]; then
        blk_options="${blk_options} rootflags=subvol=@"
    fi
    
    local rw_loglevel_options="rw loglevel=3"
    local initrd_options="initrd=intel-ucode.img initrd=initramfs-%v.img"
    
    # Create refind_linux.conf
    cat <<EOF >/mnt/boot/refind_linux.conf
"Boot with standard options"     "${blk_options} ${rw_loglevel_options} ${initrd_options}"
"Boot using fallback initramfs"  "${blk_options} ${rw_loglevel_options} initrd=intel-ucode.img initrd=initramfs-%v-fallback.img"
"Boot to terminal"               "${blk_options} ${rw_loglevel_options} ${initrd_options} systemd.unit=multi-user.target"
"Boot to single-user mode"       "${blk_options} ${rw_loglevel_options} ${initrd_options} single"
"Boot with minimal options"      "${blk_options} ${initrd_options} ro"
EOF

    # Configure refind.conf
    if [ ! -f /mnt/boot/EFI/refind/refind.conf ]; then
        error "refind.conf not found!"
    fi
    sed -i 's|#extra_kernel_version_strings|extra_kernel_version_strings|' /mnt/boot/EFI/refind/refind.conf
    sed -i 's|#fold_linux_kernels|fold_linux_kernels|' /mnt/boot/EFI/refind/refind.conf
}

# Setup pacman hook for refind
setup_pacman_hook() {
    log "Setting up pacman hook for rEFInd..."
    
    mkdir -p /mnt/etc/pacman.d/hooks
    cat <<EOF >/mnt/etc/pacman.d/hooks/refind.hook
[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install
EOF
}