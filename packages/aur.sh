#!/usr/bin/env bash

# Source required utilities
AUR_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${AUR_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install AUR packages
install_aur_packages() {
    log "Installing AUR packages..."
    
    # Get AUR packages from CSV
    local AUR_PKGS
    AUR_PKGS=$(awk -F',' '/^aur,/ {print $2}' ORS=' ' "${AUR_SCRIPT_DIR}/programs.csv")
    
    # Create a script to run inside chroot
    cat > /mnt/install_aur_packages.sh << EOF
#!/usr/bin/env bash
set -euo pipefail

# Configure passwordless sudo for the new user temporarily
echo '${NEW_USER} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp_install
chmod 440 /etc/sudoers.d/temp_install

# Install yay AUR helper
echo "Installing yay AUR helper..."
sudo -u ${NEW_USER} bash -c "
    set -euo pipefail
    cd /tmp
    if ! git clone https://aur.archlinux.org/yay-bin.git; then
        echo \"ERROR: Failed to clone yay-bin repository!\"
        exit 1
    fi
    cd yay-bin
    makepkg --noconfirm -si
    cd ..
    rm -rf yay-bin
"

# Verify yay installation
if ! which yay >/dev/null 2>&1; then
    echo "ERROR: yay was not installed properly!"
    exit 1
fi
echo "yay installed successfully at: \$(which yay)"

# Install AUR packages
echo "Installing AUR Packages..."
sudo -u ${NEW_USER} yay -S --needed --noconfirm --answerdiff=None --answerclean=None --removemake ${AUR_PKGS}

# Remove temporary sudoers rule after installation
rm -f /etc/sudoers.d/temp_install

echo "AUR packages installation completed successfully!"
EOF

    # Make script executable and run it in chroot
    chmod +x /mnt/install_aur_packages.sh
    arch-chroot /mnt ./install_aur_packages.sh || fatal_error "something went wrong while installing AUR packages!"
    
    # Clean up the script
    rm -f /mnt/install_aur_packages.sh
}