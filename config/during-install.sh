#!/usr/bin/env bash

# Source required utilities
DURING_INSTALL_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${DURING_INSTALL_SCRIPT_DIR}/../utils/logging.sh"
fi

# Source configuration modules from config/system/ directory
source "${DURING_INSTALL_SCRIPT_DIR}/system/locale.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/timezone.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/ntp.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/hosts.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/root.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/mkinitcpio.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/NetworkManager.sh"
source "${DURING_INSTALL_SCRIPT_DIR}/system/pacman.sh"

# Source bootloader modules
source "${DURING_INSTALL_SCRIPT_DIR}/../bootloader/install-refind.sh"

# Automated system configuration (no user interaction) with proper error handling
configure_system_automated() {
    log "Configuring system during installation..."
    
    # Execute configuration steps with proper error handling
    if ! configure_locale; then
        error "Failed to configure locale"
    fi
    
    if ! configure_timezone; then
        error "Failed to configure timezone"
    fi
    
    if ! update_installed_system_clock; then
        error "Failed to update system clock"
    fi
    
    if ! configure_hostname; then
        error "Failed to configure hostname"
    fi
    
    if ! configure_hosts; then
        error "Failed to configure hosts file"
    fi
    
    if ! set_root_password; then
        error "Failed to set root password"
    fi
    
    if ! configure_mkinitcpio; then
        error "Failed to configure mkinitcpio"
    fi
    
    if ! install_refind; then
        error "Failed to install rEFInd bootloader"
    fi
    
    if ! enable_networkmanager; then
        error "Failed to enable NetworkManager"
    fi
    
    if ! configure_pacman; then
        error "Failed to configure pacman"
    fi
    
    log "System configuration during installation completed successfully"
    return 0
}