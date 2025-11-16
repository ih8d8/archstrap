#!/usr/bin/env bash

# Source required utilities
LIBINPUT_GESTURES_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LIBINPUT_GESTURES_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure libinput-gestures
configure_libinput_gestures() {
    log "Configuring libinput-gestures..."
    
    # Configure passwordless sudo for the new user temporarily
    arch-chroot /mnt bash -c "echo '${NEW_USER} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp_install"
    arch-chroot /mnt chmod 440 /etc/sudoers.d/temp_install

    arch-chroot /mnt sudo -u "${NEW_USER}" libinput-gestures-setup autostart start
    
    log "Libinput-gestures configured successfully"

    # Remove temporary sudoers rule after installation
    arch-chroot /mnt rm -f /etc/sudoers.d/temp_install
}