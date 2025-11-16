#!/usr/bin/env bash

# Source required utilities
TIMEZONE_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${TIMEZONE_SCRIPT_DIR}/../../utils/logging.sh"
fi

# Auto-detect timezone based on IP
detect_timezone() {
    log "Auto-detecting timezone..."
    
    # Try multiple services for timezone detection
    local timezone=""
    
    # Try worldtimeapi.org first
    if command -v curl >/dev/null 2>&1; then
        timezone=$(curl -s "http://worldtimeapi.org/api/ip" 2>/dev/null | grep -o '"timezone":"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
    fi
    
    # Fallback to ipapi.co
    if [[ -z "${timezone}" ]] && command -v curl >/dev/null 2>&1; then
        timezone=$(curl -s "http://ipapi.co/timezone" 2>/dev/null || true)
    fi
    
    # Final fallback to a reasonable default
    if [[ -z "${timezone}" ]] || [[ ! -f "/usr/share/zoneinfo/${timezone}" ]]; then
        warning "Could not auto-detect timezone, using UTC as default"
        timezone="UTC"
    fi
    
    TIME_ZONE="${timezone}"
    log "Detected timezone: ${TIME_ZONE}"
}

# Configure timezone
configure_timezone() {
    log "Configuring timezone..."
    
    # Configure timezone
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"${TIME_ZONE}" /etc/localtime
    arch-chroot /mnt hwclock --systohc
}