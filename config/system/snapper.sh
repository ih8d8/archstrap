#!/usr/bin/env bash

# Source required utilities
SNAPPER_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SNAPPER_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure snapper for automatic snapshots
configure_snapper() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    if [[ "${filesystem}" != "btrfs" ]]; then
        log "Snapper only works with Btrfs, skipping configuration for ${filesystem}"
        return 0
    fi
    
    log "Configuring snapper for Btrfs snapshots..."
    
    # Create snapper config for root subvolume only
    configure_root_snapshots
    
    # Enable snapper services
    enable_snapper_services
    
    log "Snapper configuration completed successfully"
}

# Configure snapshots for root subvolumes
configure_root_snapshots() {
    log "Creating snapper configuration for root subvolume..."
    
    # Create snapper config with D-Bus daemon running
    log "Starting D-Bus and creating snapper config for root filesystem..."
    arch-chroot /mnt /bin/bash -c "
        # Clean up any existing D-Bus PID file
        rm -f /run/dbus/pid
        
        # Ensure D-Bus directory exists
        mkdir -p /run/dbus
        
        # Start D-Bus daemon in the background
        dbus-daemon --system --fork
        
        # Create snapper config
        snapper -c root create-config /
        
        # Stop D-Bus daemon and clean up
        pkill -f 'dbus-daemon --system' || true
        rm -f /run/dbus/pid || true
    "
    
    if [[ $? -ne 0 ]]; then
        fatal_error "Failed to create snapper root configuration"
    fi
    
    # Configure timeline settings according to requirements
    log "Configuring snapper timeline settings..."
    arch-chroot /mnt /bin/bash -c "
        # Update the snapper config file with custom timeline settings
        config_file='/etc/snapper/configs/root'
        
        # Update timeline settings
        sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE=\"1800\"/' \"\$config_file\"
        sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY=\"5\"/' \"\$config_file\"
        sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY=\"7\"/' \"\$config_file\"
        sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY=\"0\"/' \"\$config_file\"
        sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY=\"0\"/' \"\$config_file\"
        sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY=\"0\"/' \"\$config_file\"
        
        # Verify the configuration was updated
        echo 'Updated snapper configuration:'
        grep -E '^TIMELINE_(MIN_AGE|LIMIT_)' \"\$config_file\" || true
    "
    
    if [[ $? -ne 0 ]]; then
        fatal_error "Failed to configure snapper timeline settings"
    fi
        
    log "Snapper root configuration created and configured successfully"
    log "Timeline settings: 5 hourly, 7 daily, no weekly/monthly/yearly snapshots"
}


# Enable snapper systemd services
enable_snapper_services() {
    log "Enabling snapper systemd services..."
    
    # Enable snapper timeline service for automatic snapshots
    if ! arch-chroot /mnt systemctl enable snapper-timeline.timer 2>/dev/null; then
        log "Warning: Failed to enable snapper-timeline.timer"
    fi
    
    # Enable snapper cleanup service for automatic cleanup
    if ! arch-chroot /mnt systemctl enable snapper-cleanup.timer 2>/dev/null; then
        log "Warning: Failed to enable snapper-cleanup.timer"
    fi
    
    log "Snapper services configuration completed"
}

# Create initial snapshots
create_initial_snapshots() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    
    if [[ "${filesystem}" != "btrfs" ]]; then
        return 0
    fi
    
    log "Creating initial snapshots..."
    
    # Create initial root snapshot
    if ! arch-chroot /mnt /bin/bash -c "
        # Start DBus if not running
        if ! pgrep -x dbus-daemon > /dev/null; then
            dbus-daemon --system --fork 2>/dev/null || true
        fi
        
        # Create initial snapshot
        snapper -c root create --description 'Initial system snapshot' 2>/dev/null
    "; then
        log "Warning: Could not create initial snapshot via snapper, will be created on first boot"
    fi
    
    log "Initial snapshot configuration completed"
}