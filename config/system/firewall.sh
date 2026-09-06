#!/usr/bin/env bash

# Source required utilities
FIREWALL_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${FIREWALL_SCRIPT_DIR}/../../utils/logging.sh"
fi

# set -e is off while tasks run (execute_task disables it), so an unchecked
# failure here would still end in "configured successfully". Every UFW call
# goes through this helper; callers accumulate failures.
ufw_chroot() {
    arch-chroot /mnt ufw "$@" || { error "ufw $*"; return 1; }
}

# Configure firewall using UFW and UFW-Docker
configure_firewall() {
    log "Configuring firewall with UFW and UFW-Docker..."
    local failed=0

    # Reset UFW to defaults
    ufw_chroot --force reset || failed=1

    # Set default policies - deny all incoming, allow outgoing
    ufw_chroot default deny incoming || failed=1
    ufw_chroot default allow outgoing || failed=1

    # Allow KDE Connect ports (TCP 1714-1764 and UDP 1714-1764)
    log "Allowing KDE Connect ports (1714-1764)..."
    ufw_chroot allow 1714:1764/tcp comment "KDE Connect TCP" || failed=1
    ufw_chroot allow 1714:1764/udp comment "KDE Connect UDP" || failed=1

    # libvirt's default NAT network: DHCP and DNS reach dnsmasq on the host
    # side, and the route rule permits forwarded guest traffic that the default
    # routed policy drops. That forwarding covers every routed destination, LAN
    # and VPN included.
    #
    # The bridge name is read from libvirt's own network definition rather than
    # assumed. libvirtd is not running inside the chroot, so virsh cannot answer
    # -- but the libvirt package ships this file, so it is readable offline.
    # Newlines are squashed first so the match does not depend on the element
    # staying on one line.
    local libvirt_net="/mnt/etc/libvirt/qemu/networks/default.xml"
    local virt_bridge=""
    if [[ -f "${libvirt_net}" ]]; then
        virt_bridge="$(tr '\n' ' ' < "${libvirt_net}" \
            | sed -n "s/.*<bridge[^>]*name=['\"]\([^'\"]*\)['\"].*/\1/p" | head -1)"
    fi

    if [[ -n "${virt_bridge}" ]]; then
        log "Allowing libvirt guest networking on ${virt_bridge}..."
        ufw_chroot allow in on "${virt_bridge}" to any port 67 proto udp comment "libvirt guest DHCP" || failed=1
        ufw_chroot allow in on "${virt_bridge}" to any port 53 comment "libvirt guest DNS" || failed=1
        ufw_chroot route allow in on "${virt_bridge}" comment "libvirt guest egress" || failed=1
    else
        warning "libvirt default network not found; skipping guest firewall rules"
    fi

    # Allow SSH (if needed for remote management)
    # Uncomment the next line if SSH access is required
    # ufw_chroot allow ssh comment "SSH" || failed=1

    # Enable UFW
    ufw_chroot --force enable || failed=1

    # Configure UFW-Docker to manage Docker container networking
    log "Configuring UFW-Docker integration..."
    arch-chroot /mnt ufw-docker install || { error "ufw-docker install"; failed=1; }

    # Enable UFW logging (optional - can be set to 'off', 'low', 'medium', 'high', 'full')
    ufw_chroot logging on || failed=1

    if [[ ${failed} -ne 0 ]]; then
        error "Firewall configuration completed with errors"
        return 1
    fi

    log "Firewall configured successfully"
    return 0
}

# Enable UFW service
enable_firewall_service() {
    log "Enabling UFW service..."

    if ! arch-chroot /mnt systemctl enable ufw; then
        error "Failed to enable ufw service"
        return 1
    fi

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