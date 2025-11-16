#!/usr/bin/env bash

# Source required utilities
UDEV_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${UDEV_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure udev rules
configure_udev() {
    log "Configuring udev rules..."
    
    mkdir -p /mnt/etc/udev/rules.d
    
    cat > /mnt/etc/udev/rules.d/98-lowbat.rules << EOF
# notify the user when battery level drops below 10% or lower
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-9]|10", RUN+="/home/${NEW_USER}/.local/bin/notify-battery-status"
EOF

    cat > /mnt/etc/udev/rules.d/99-lowbat.rules << 'EOF'
# Suspend the system when battery level drops below 5% or lower
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl suspend"
EOF
    
    log "Udev rules configured successfully"
}