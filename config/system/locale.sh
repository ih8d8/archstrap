#!/usr/bin/env bash

# Source required utilities
LOCALE_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${LOCALE_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Configure system locale
configure_locale() {
    log "Configuring system locale..."
    
    # Configure locale
    sed -i -e 's|#fa_IR UTF-8|fa_IR UTF-8|' -e 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|' /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
}