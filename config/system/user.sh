#!/usr/bin/env bash

# Source required utilities
USER_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${USER_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Automated user creation (no user interaction) with proper error handling
add_new_user_automated() {
    log "Adding new user: ${NEW_USER}..."
    
    # Validate required variables
    if [[ -z "${NEW_USER:-}" ]]; then
        fata_error "NEW_USER variable is not set"
    fi
    
    if [[ -z "${USER_PASSWORD:-}" ]]; then
        fata_error "USER_PASSWORD variable is not set"
    fi
    
    # Create user with error checking
    if ! arch-chroot /mnt useradd -m -g wheel "${NEW_USER}"; then
        fata_error "Failed to create user ${NEW_USER}"
    fi
    
    # Set user password using piped input with error checking
    if ! echo "${NEW_USER}:${USER_PASSWORD}" | arch-chroot /mnt chpasswd; then
        fata_error "Failed to set password for user ${NEW_USER}"
    fi
    
    # Add user to additional groups with error checking
    if ! arch-chroot /mnt usermod -aG storage,video,input "${NEW_USER}"; then
        fata_error "Failed to add user ${NEW_USER} to additional groups"
    fi
    
    log "User ${NEW_USER} created successfully"
    return 0
}

# Add new user to required system groups
add_new_user_to_groups() {
    log "Adding new user to required system groups..."
    
    # Add user to required groups
    local -a USER_GROUPS=(libvirt docker wireshark lp)
    for GROUP in "${USER_GROUPS[@]}"; do
        arch-chroot /mnt usermod -a -G "${GROUP}" "${NEW_USER}" || warning "Failed to add user to group ${GROUP}"
    done
    
    log "User successfully added to system groups"
}

# Create user directories and mount points with proper ownership
create_user_directories() {
    log "Creating user directories and mount points..."
    
    # Validate NEW_USER variable
    if [[ -z "${NEW_USER:-}" ]]; then
        fatal_error "NEW_USER variable is not set or empty"
    fi
    
    # Define user directories to create
    local -a USER_DIRS=(
        "Cloud"
        "Documents"
        "Downloads"
        "Notes"
        "Pictures"
        "Recordings"
        "Shared"
        ".local"
        ".local/bin"
    )
    
    # Define system mount points to create with proper ownership
    local -a MOUNT_POINTS=(
        "/mnt/nfs"
        "/mnt/sshfs"
    )
    
    # Create user directories in home folder
    log "Creating user directories in /home/${NEW_USER}..."
    for dir in "${USER_DIRS[@]}"; do
        local full_path="/mnt/home/${NEW_USER}/${dir}"
        if ! arch-chroot /mnt mkdir -p "${full_path#/mnt}"; then
            fatal_error "Failed to create directory ${full_path#/mnt}"
            return 1
        fi
        
        # Set proper ownership
        if ! arch-chroot /mnt chown "${NEW_USER}:wheel" "${full_path#/mnt}"; then
            fatal_error "Failed to set ownership for ${full_path#/mnt}"
            return 1
        fi
        
        log "Created and set ownership for ${full_path#/mnt}"
    done
    
    # Create system mount points with proper ownership
    log "Creating system mount points..."
    for mount_point in "${MOUNT_POINTS[@]}"; do
        local chroot_path="${mount_point}"
        if ! arch-chroot /mnt mkdir -p "${chroot_path}"; then
            fatal_error "Failed to create mount point ${chroot_path}"
            return 1
        fi
        
        # Set proper ownership for user access
        if ! arch-chroot /mnt chown "${NEW_USER}:wheel" "${chroot_path}"; then
            fatal_error "Failed to set ownership for ${chroot_path}"
            return 1
        fi
        
        log "Created mount point ${chroot_path} with ${NEW_USER}:wheel ownership"
    done
    
    log "Successfully created all user directories and mount points"
    return 0
}