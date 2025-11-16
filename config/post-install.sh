#!/usr/bin/env bash

# Source required utilities
POST_INSTALL_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${POST_INSTALL_SCRIPT_DIR}/../utils/logging.sh"
fi

# Source system configuration modules
source "${POST_INSTALL_SCRIPT_DIR}/system/libinput.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/polkit.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/libinput-gestures.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/NetworkManager.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/udev.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/journald.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/gvfs.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/systemd-services.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/user.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/luks-ownership.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/snapper.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/pacman.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/firewall.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/local-bin.sh"
source "${POST_INSTALL_SCRIPT_DIR}/system/crontab.sh"

# Source application configuration modules
source "${POST_INSTALL_SCRIPT_DIR}/apps/dnscrypt-proxy.sh"
source "${POST_INSTALL_SCRIPT_DIR}/apps/virt-manager.sh"
source "${POST_INSTALL_SCRIPT_DIR}/apps/nano.sh"
source "${POST_INSTALL_SCRIPT_DIR}/apps/proxychains.sh"
source "${POST_INSTALL_SCRIPT_DIR}/apps/vi.sh"
source "${POST_INSTALL_SCRIPT_DIR}/apps/sddm.sh"

# Source swap utilities
source "${POST_INSTALL_SCRIPT_DIR}/../disk/swap.sh"

# Configure system post-installation with proper error handling
configure_system_post_install() {
    log "Configuring system post-installation..."
    
    # This function orchestrates all the post-install config modules with proper error handling
    
    if ! configure_libinput; then
        fatal_error "Failed to configure libinput"
    fi
    
    if ! configure_dnscrypt_proxy; then
        fatal_error "Failed to configure dnscrypt-proxy"
    fi
    
    if ! configure_virt_manager; then
        fatal_error "Failed to configure virt-manager"
    fi
    
    if ! configure_polkit; then
        fatal_error "Failed to configure polkit"
    fi
    
    if ! configure_nano; then
        fatal_error "Failed to configure nano"
    fi
    
    if ! configure_libinput_gestures; then
        fatal_error "Failed to configure libinput-gestures"
    fi
    
    if ! configure_proxychains; then
        fatal_error "Failed to configure proxychains"
    fi
    
    if ! configure_networkmanager; then
        fatal_error "Failed to configure NetworkManager"
    fi
    
    if ! configure_udev; then
        fatal_error "Failed to configure udev rules"
    fi
    
    if ! configure_journald; then
        fatal_error "Failed to configure journald"
    fi
    
    if ! configure_gvfs; then
        fatal_error "Failed to configure gvfs"
    fi
    
    if ! configure_vi; then
        fatal_error "Failed to configure vi"
    fi
    
    if ! configure_sddm; then
        fatal_error "Failed to configure SDDM"
    fi
    
    if ! enable_services; then
        fatal_error "Failed to enable services"
    fi
    
    if ! disable_services; then
        fatal_error "Failed to disable services"
    fi
    
    if ! add_new_user_to_groups; then
        fatal_error "Failed to add user to groups"
    fi
    
    if ! create_swapfile; then
        fatal_error "Failed to create swapfile"
    fi
    
    if ! set_secondary_luks_ownership; then
        fatal_error "Failed to set secondary LUKS ownership"
    fi
    
    if ! configure_snapper; then
        fatal_error "Failed to configure snapper"
    fi
    
    if ! create_initial_snapshots; then
        fatal_error "Failed to create initial snapshots"
    fi
    
    if ! create_user_directories; then
        fatal_error "Failed to create user directories and mount points"
    fi
    
    if ! remove_orphan_packages; then
        fatal_error "Failed to remove orphan packages"
    fi
    
    if ! configure_firewall; then
        fatal_error "Failed to configure firewall"
    fi
    
    if ! enable_firewall_service; then
        fatal_error "Failed to enable firewall service"
    fi
    
    if ! configure_user_local_bin; then
        fatal_error "Failed to configure user local bin directory"
    fi
    
    if ! configure_crontab; then
        fatal_error "Failed to configure crontab entries"
    fi
    
    # Run user initialization script if it exists
    local init_user_script="${POST_INSTALL_SCRIPT_DIR}/dotfiles/extra/init-scripts/init-user.sh"
    if [[ -f "$init_user_script" ]]; then
        log "Found user initialization script, executing..."
        if ! bash "${init_user_script}" "/mnt" "${NEW_USER}"; then
            fatal_error "Failed to execute user initialization script"
        fi
        log "User initialization script executed successfully"
    fi
    
    log "System post-installation configuration completed successfully!"
    return 0
}