#!/usr/bin/env bash

# Source required utilities
NVIDIA_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${NVIDIA_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install NVIDIA drivers
install_nvidia_drivers() {
    # Configure passwordless sudo for the new user temporarily
    arch-chroot /mnt bash -c "echo '${NEW_USER} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp_install"
    arch-chroot /mnt chmod 440 /etc/sudoers.d/temp_install

    log "Installing NVIDIA drivers..."
    if arch-chroot /mnt lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
        arch-chroot /mnt sudo -u "${NEW_USER}" yay -S --needed --noconfirm --answerdiff=None --answerclean=None --removemake nvidia nvidia-lts nvidia-settings nvidia-prime libva-nvidia-driver-git cuda cudnn cuda-tools || fatal_error "something went wrong while installing nvidia drivers!"
    else
        log "NVIDIA GPU not detected, skipping NVIDIA driver installation."
    fi

    # Remove temporary sudoers rule after installation
    arch-chroot /mnt rm -f /etc/sudoers.d/temp_install
}