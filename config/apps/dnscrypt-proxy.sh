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
       /etc/dnscrypt-proxy/dnscrypt-proxy.toml

echo "dnscrypt-proxy configuration completed!"
EOF

    chmod +x /mnt/configure_dnscrypt.sh
    arch-chroot /mnt ./configure_dnscrypt.sh || error "Failed to configure dnscrypt-proxy!"
    rm -f /mnt/configure_dnscrypt.sh
    
    # Add the resolvconf-dnscrypt-proxy systemd service
    add_resolvconf_dnscrypt_proxy_systemd_service
}

# Add resolvconf-dnscrypt-proxy systemd service
add_resolvconf_dnscrypt_proxy_systemd_service() {
    log "Adding resolvconf-dnscrypt-proxy systemd service..."
    
    # Create resolvconf-dnscrypt-proxy service
    cat > /mnt/etc/systemd/system/resolvconf-dnscrypt-proxy.service << 'EOF'
[Unit]
Description=systemd service for setting /etc/resolv.conf based on dnscrypt-proxy requirements

[Service]
ExecStart=/usr/bin/bash -c '/usr/bin/echo -e "nameserver ::1\nnameserver 127.0.0.1\noptions edns0 single-request-reopen" | /usr/bin/resolvconf -a dnscrypt; /usr/bin/resolvconf -u'

[Install]
WantedBy=multi-user.target
EOF
    
    log "resolvconf-dnscrypt-proxy systemd service added successfully"
}