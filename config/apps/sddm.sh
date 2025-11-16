#!/usr/bin/env bash

# Source required utilities
SDDM_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${SDDM_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure SDDM
configure_sddm() {
    log "Configuring SDDM theme..."
    
    mkdir -p /mnt/usr/share/wayland-sessions
    cat > /mnt/usr/share/wayland-sessions/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF

    mkdir -p /mnt/etc/sddm.conf.d
    cat > /mnt/etc/sddm.conf.d/custom.conf << 'EOF'
[General]
Numlock=on

[Theme]
Current=simple-sddm
EOF
    
    log "SDDM configured successfully"
}