#!/usr/bin/env bash

# Source required utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SCRIPT_DIR}/../../utils/logging.sh"
fi

# Function to copy bin scripts to user's local bin directory
configure_user_local_bin() {
    log "Configuring user local bin directory..."
    
    # Create .local/bin directory if it doesn't exist
    if ! arch-chroot /mnt sudo -u "${NEW_USER}" mkdir -p "/home/${NEW_USER}/.local/bin"; then
        fatal_error "Failed to create .local/bin directory for user ${NEW_USER}"
    fi
    
    # Copy all scripts from config/bin/ to user's .local/bin/
    log "Copying scripts from config/bin/ to /home/${NEW_USER}/.local/bin/"
    
    # Automatically discover all files in the bin directory
    for script_path in "${SCRIPT_DIR}/../bin"/*; do
        if [[ -f "${script_path}" ]]; then
            local script="$(basename "${script_path}")"
            
            if ! cp "${script_path}" "/mnt/home/${NEW_USER}/.local/bin/"; then
                fatal_error "Failed to copy ${script} to user's local bin directory"
            fi
            
            # Make script executable and set correct ownership
            if ! arch-chroot /mnt chmod +x "/home/${NEW_USER}/.local/bin/${script}"; then
                fatal_error "Failed to make ${script} executable"
            fi
            
            if ! arch-chroot /mnt chown "${NEW_USER}:wheel" "/home/${NEW_USER}/.local/bin/${script}"; then
                fatal_error "Failed to set ownership for ${script}"
            fi
            
            log "Successfully copied and configured ${script}"
        fi
    done
    
    log "User local bin directory configuration completed successfully!"
    return 0
}