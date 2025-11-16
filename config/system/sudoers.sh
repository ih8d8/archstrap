#!/usr/bin/env bash

# Source required utilities
SUDOERS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SUDOERS_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Create sudoers custom config file
create_sudoers_config() {
    log "Creating sudoers custom configuration..."
    
    cat <<EOF >/mnt/etc/sudoers.d/custom_configs
Defaults        !tty_tickets
Defaults        env_reset,timestamp_timeout=60
Cmnd_Alias      NOPASSWD_COMMANDS = /usr/bin/shutdown, /usr/bin/poweroff, /usr/bin/reboot, /usr/bin/wg-quick, \\
                                    /usr/bin/mount, /usr/bin/umount, /usr/bin/pingtunnel, /usr/bin/pkill pingtunnel

%wheel ALL=(ALL) NOPASSWD: NOPASSWD_COMMANDS
EOF
}

# Configure sudoers
configure_sudoers() {
    log "Configuring sudoers..."
    
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
}