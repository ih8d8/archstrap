#!/usr/bin/env bash

# Source required utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SCRIPT_DIR}/../../utils/logging.sh"
fi

# Function to configure cron jobs for user
configure_user_crontab() {
    log "Adding cron jobs for user ${NEW_USER}..."
    
    # Add cron jobs for the user (runs as NEW_USER)
    if ! arch-chroot /mnt sudo -u "${NEW_USER}" bash -c "(
        echo \"*/10 * * * * export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; export DISPLAY=:0; . \${HOME}/.profile; /home/${NEW_USER}/.local/bin/mailsync\"
        echo \"0 */4 * * * /home/${NEW_USER}/.local/bin/cron-pkg-update\"
    ) | crontab -"; then
        error "Failed to add cron jobs for user ${NEW_USER}"
        return 1
    fi
    
    log "Successfully added cron jobs for user ${NEW_USER}"
    return 0
}

# Function to configure cron jobs for root
configure_root_crontab() {
    log "Adding cron jobs for root..."
    
    # Add cron jobs for root
    if ! arch-chroot /mnt bash -c "(
        echo \"0 */12 * * * /home/${NEW_USER}/.local/bin/update-adblocker-list\"
    ) | crontab -"; then
        error "Failed to add cron jobs for root"
        return 1
    fi
    
    log "Successfully added cron jobs for root"
    return 0
}

# Main function to configure all crontab entries
configure_crontab() {
    log "Configuring crontab entries..."
    
    if ! configure_user_crontab; then
        error "Failed to configure user crontab"
        return 1
    fi
    
    if ! configure_root_crontab; then
        error "Failed to configure root crontab"
        return 1
    fi
    
    log "Crontab configuration completed successfully!"
    return 0
}