#!/usr/bin/env bash

# Source required utilities
SDDM_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SDDM_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure SDDM
configure_sddm() {
    log "Configuring SDDM theme..."
    
    mkdir -p /mnt/etc/sddm.conf.d
    cat > /mnt/etc/sddm.conf.d/custom.conf << 'EOF'
[General]
Numlock=on

[Theme]
Current=simple-sddm
EOF

    # The disk is always LUKS-encrypted, so the passphrase typed in the
    # initramfs is already the authentication boundary; a second prompt at the
    # greeter guards nothing an attacker holding the disk would not defeat
    # first. Session names a file in /usr/share/wayland-sessions, which the
    # hyprland package owns. Relogin is left at its default of false, so
    # logging out still returns to the greeter as an escape hatch.
    local session="hyprland.desktop"

    if [[ -z "${NEW_USER:-}" ]]; then
        warning "NEW_USER is unset; skipping SDDM autologin"
    elif [[ ! -f "/mnt/usr/share/wayland-sessions/${session}" ]]; then
        # Without the session file SDDM autologin fails and drops back to the
        # greeter, so skip it rather than ship a config that points at nothing.
        warning "${session} not found; skipping SDDM autologin"
    else
        log "Enabling SDDM autologin for ${NEW_USER}..."
        cat > /mnt/etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=${NEW_USER}
Session=${session}
EOF
    fi

    log "SDDM configured successfully"
}
