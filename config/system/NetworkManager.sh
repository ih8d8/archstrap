#!/usr/bin/env bash

# Source required utilities
NETWORKMANAGER_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${NETWORKMANAGER_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure NetworkManager
configure_networkmanager() {
    log "Configuring NetworkManager..."
    
    mkdir -p /mnt/etc/NetworkManager/conf.d
    
    cat > /mnt/etc/NetworkManager/conf.d/rc-manager.conf << 'EOF'
[main]
rc-manager=resolvconf
EOF

    cat > /mnt/etc/NetworkManager/conf.d/unmanaged.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wg*
EOF
    
    log "NetworkManager configured successfully"
}

# Enable NetworkManager
enable_networkmanager() {
    log "Enabling NetworkManager..."
    
    arch-chroot /mnt systemctl enable NetworkManager
    
    log "NetworkManager enabled successfully"
}