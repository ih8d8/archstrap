#!/usr/bin/env bash

# Source required utilities
DNSCRYPT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${DNSCRYPT_SCRIPT_DIR}/../../utils/logging.sh"

# Configure dnscrypt-proxy
configure_dnscrypt_proxy() {
    log "Configuring dnscrypt-proxy..."
    
    # Create chroot script for dnscrypt-proxy configuration
    cat > /mnt/configure_dnscrypt.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "#################### Configure dnscrypt-proxy ####################"
sudo sed -i -e 's|# blocked_names_file|blocked_names_file|' \
       -e 's|doh_servers = true|doh_servers = false|' \
       -e 's|require_dnssec = false|require_dnssec = true|' \
       -e 's|skip_incompatible = false|skip_incompatible = true|' \
       -e '/skip_incompatible = true/i\routes = [\
    { server_name='\''*'\'' , via=['\''*'\'' ] },\
]\
' \
       -e 's|^# log_file = '\''/var/log/dnscrypt-proxy/blocked-names.log'\''|log_file = '\''/var/log/dnscrypt-proxy/blocked-names.log'\''|' \
       -e 's|^# file = '\''/var/log/dnscrypt-proxy/query.log'\''|file = '\''/var/log/dnscrypt-proxy/query.log'\''|' \
       -e 's|^# log_file = '\''/var/log/dnscrypt-proxy/blocked-ips.log'\''|log_file = '\''/var/log/dnscrypt-proxy/blocked-ips.log'\''|' \
       -e '/\[monitoring_ui\]/,/^\[/{s|^enabled = false|enabled = true|}' \
       -e '/\[monitoring_ui\]/,/^\[/{s|^listen_address = "127.0.0.1:8080"|listen_address = "127.0.0.1:5380"|}' \
       -e '/\[monitoring_ui\]/,/^\[/{s|^username = "admin"|username = ""|}' \
       -e '/\[monitoring_ui\]/,/^\[/{s|^password = "changeme"|password = ""|}' \
       -e '/\[monitoring_ui\]/,/^\[/{s|^privacy_level = 1|privacy_level = 0|}' \
       /etc/dnscrypt-proxy/dnscrypt-proxy.toml

echo "dnscrypt-proxy configuration completed!"
EOF

    chmod +x /mnt/configure_dnscrypt.sh
    arch-chroot /mnt ./configure_dnscrypt.sh || error "Failed to configure dnscrypt-proxy!"
    rm -f /mnt/configure_dnscrypt.sh
    
    # Hand DNS over to systemd-resolved, resolving through dnscrypt-proxy
    configure_resolved_for_dnscrypt
}

# Point systemd-resolved at dnscrypt-proxy
configure_resolved_for_dnscrypt() {
    log "Configuring systemd-resolved to resolve through dnscrypt-proxy..."

    mkdir -p /mnt/etc/systemd/resolved.conf.d

    # Kept separate from the drop-in below because toggle-dnscrypt-proxy renames
    # that one out of the way to switch DNSCrypt off: the fallback servers must
    # stay disabled in both states. Without this, resolved quietly resolves
    # through plaintext Google/Cloudflare/Quad9 whenever its configured server
    # is unreachable.
    cat > /mnt/etc/systemd/resolved.conf.d/00-no-fallback.conf << 'EOF'
[Resolve]
FallbackDNS=
EOF

    cat > /mnt/etc/systemd/resolved.conf.d/10-dnscrypt.conf << 'EOF'
[Resolve]
# dnscrypt-proxy listens here. IPv4 only: it does not bind [::1]:53, and
# listing ::1 makes every lookup pay three refused attempts first.
DNS=127.0.0.1
# "~." routes every name to the server above, outranking the per-link resolvers
# DHCP hands out - otherwise the network's own DNS would answer. Tailscale's
# per-interface domains are more specific, so tailnet names still win.
Domains=~.
# dnscrypt-proxy already enforces DNSSEC upstream (require_dnssec = true).
DNSSEC=no
DNSOverTLS=no
EOF

    # resolv.conf points at the stub resolver rather than at 127.0.0.1 directly,
    # so per-link search domains and Tailscale's split routing still apply.
    ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

    log "systemd-resolved configured successfully"
}
