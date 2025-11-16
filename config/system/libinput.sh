#!/usr/bin/env bash

# Source required utilities
LIBINPUT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LIBINPUT_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure libinput
configure_libinput() {
    log "Configuring libinput..."
    
    mkdir -p /mnt/etc/X11/xorg.conf.d
    cat > /mnt/etc/X11/xorg.conf.d/40-libinput.conf << 'EOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
        Option "Tapping" "on"
        Option "TappingButtonMap" "lrm"
        Option "AccelSpeed" "0.1"
EndSection
EOF
    
    log "Libinput configured successfully"
}