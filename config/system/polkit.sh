#!/usr/bin/env bash

# Source required utilities
POLKIT_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${POLKIT_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure polkit rules
configure_polkit() {
    log "Configuring polkit rules..."
    
    mkdir -p /mnt/etc/polkit-1/rules.d
    cat > /mnt/etc/polkit-1/rules.d/00-mount-internal.rules << 'EOF'
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
	 return polkit.Result.YES;
      }
});
EOF
    
    log "Polkit rules configured successfully"
}