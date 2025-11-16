#!/usr/bin/env bash

if [[ -z "${LOG_FILE:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Check system prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if boot type is UEFI
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        fatal_error "Boot type is not UEFI!"
    fi
    
    # Check internet connection
    if ! ping -q -c 1 archlinux.org >/dev/null 2>&1; then
        fatal_error "No internet connection!"
    fi
    
    log "Prerequisites check passed"
}
