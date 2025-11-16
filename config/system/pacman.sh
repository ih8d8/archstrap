#!/usr/bin/env bash

# Source required utilities
PACMAN_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${PACMAN_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure pacman and makepkg
configure_pacman() {
    log "Configuring pacman and makepkg..."
    
    # Enable colors and candy progress bar
    grep "^Color" /mnt/etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /mnt/etc/pacman.conf
    grep "ILoveCandy" /mnt/etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /mnt/etc/pacman.conf
    grep "^ParallelDownloads" /mnt/etc/pacman.conf >/dev/null || sed -i "s/^#ParallelDownloads/ParallelDownloads/" /mnt/etc/pacman.conf
    
    # Use all cores for compilation
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /mnt/etc/makepkg.conf
    
    log "Pacman and makepkg configured successfully"
}

# Configure fastest mirrors using reflector
configure_mirrors() {
    log "Configuring fastest mirrors using reflector..."
    
    # Create a script to run inside chroot for mirror configuration
    cat > /mnt/configure_mirrors.sh << 'EOF'
#!//usr/bin/env bash
set -euo pipefail

# Install reflector if not already available
if ! command -v reflector >/dev/null 2>&1; then
    echo "Installing reflector..."
    pacman -Sy --noconfirm reflector
fi

# Backup original mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Generate new mirrorlist with fastest mirrors
echo "Generating new mirrorlist with fastest mirrors..."
reflector --verbose --latest 20 --country US --protocol https --sort rate --score 10 --save /etc/pacman.d/mirrorlist || {
    echo "Warning: Reflector failed, trying with fewer options..."
    reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || {
        echo "Warning: Reflector failed again, restoring backup mirrorlist..."
        cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
        exit 1
    }
}

echo "Mirrors configured successfully"
echo "Top 5 mirrors selected:"
cat /etc/pacman.d/mirrorlist | grep "^Server" | head -5
EOF

    # Make script executable and run it in chroot
    chmod +x /mnt/configure_mirrors.sh
    arch-chroot /mnt ./configure_mirrors.sh || error "Mirror configuration failed!"
    
    # Clean up the script
    rm -f /mnt/configure_mirrors.sh
}

# Remove unused orphan packages
remove_orphan_packages() {
    log "Checking for unused orphan packages..."
    
    # Check if there are any orphan packages to remove
    local orphans
    orphans=$(arch-chroot /mnt pacman -Qtdq 2>/dev/null || true)
    
    if [[ -n "$orphans" ]]; then
        log "Found orphan packages to remove:"
        echo "$orphans"
        
        log "Removing unused orphan packages..."
        if arch-chroot /mnt pacman -Rns --noconfirm $orphans; then
            log "Successfully removed orphan packages"
        else
            warning "Failed to remove some orphan packages"
            return 1
        fi
    else
        log "No orphan packages found to remove"
    fi
    
    return 0
}