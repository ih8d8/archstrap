#!/usr/bin/env bash

# Source required utilities
FIREWALL_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${FIREWALL_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure firewall using UFW and UFW-Docker
configure_firewall() {
    log "Configuring firewall with UFW and UFW-Docker..."
    
    # Reset UFW to defaults
    arch-chroot /mnt ufw --force reset
    
    # Set default policies - deny all incoming, allow outgoing
    arch-chroot /mnt ufw default deny incoming
    arch-chroot /mnt ufw default allow outgoing
    
    # Allow KDE Connect ports (TCP 1714-1764 and UDP 1714-1764)
    log "Allowing KDE Connect ports (1714-1764)..."
    arch-chroot /mnt ufw allow 1714:1764/tcp comment "KDE Connect TCP"
    arch-chroot /mnt ufw allow 1714:1764/udp comment "KDE Connect UDP"
    
    # Allow SSH (if needed for remote management)
    # Uncomment the next line if SSH access is required
    # arch-chroot /mnt ufw allow ssh comment "SSH"
    
    # Enable UFW
    arch-chroot /mnt ufw --force enable

    # Configure UFW-Docker to manage Docker container networking
    log "Configuring UFW-Docker integration..."
    
    # Install UFW-Docker rules
    arch-chroot /mnt ufw-docker install
    
    # Set UFW-Docker to deny all by default
    arch-chroot /mnt ufw-docker reset
    
    # Enable UFW logging (optional - can be set to 'off', 'low', 'medium', 'high', 'full')
    arch-chroot /mnt ufw logging on
    
    log "Firewall configured successfully"
    return 0
}

# Enable UFW service
enable_firewall_service() {
    log "Enabling UFW service..."
    
    arch-chroot /mnt systemctl enable ufw
    
    log "UFW service enabled successfully"
    return 0
}

# Display firewall status (for verification)
display_firewall_status() {
    log "Current firewall configuration:"
    
    # Show UFW status
    arch-chroot /mnt ufw status verbose || warning "Could not display UFW status"
    
    # Show UFW-Docker status
    arch-chroot /mnt ufw-docker status || warning "Could not display UFW-Docker status"
    
    return 0
}