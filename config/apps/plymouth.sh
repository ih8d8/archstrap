#!/usr/bin/env bash

# Source required utilities
PLYMOUTH_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${PLYMOUTH_SCRIPT_DIR}/../../utils/logging.sh"
fi

PLYMOUTH_THEME="obsidian"

# Add the plymouth hook so the splash owns the console before the LUKS prompt.
# This runs post-install rather than alongside the other mkinitcpio work,
# because that stage runs before packages are installed and mkinitcpio fails
# outright on a hook whose script is not on disk yet.
add_plymouth_hook() {
    local conf="/mnt/etc/mkinitcpio.conf"

    if grep -q '^HOOKS=.*[( ]plymouth[ )]' "${conf}"; then
        log "Plymouth hook already present in mkinitcpio.conf"
        return 0
    fi

    # The hook has to sit after whichever component sets up the console, so the
    # splash is up before sd-encrypt asks for the passphrase.
    if grep -q '^HOOKS=.*systemd' "${conf}"; then
        sed -i '/^HOOKS=/s/\bsystemd\b/systemd plymouth/' "${conf}"
    else
        sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' "${conf}"
    fi

    grep -q '^HOOKS=.*[( ]plymouth[ )]' "${conf}"
}

# Configure Plymouth
configure_plymouth() {
    log "Configuring Plymouth boot splash..."

    if ! arch-chroot /mnt pacman -Qq plymouth &>/dev/null; then
        warning "plymouth is not installed; skipping boot splash configuration"
        return 0
    fi

    local source_dir="${PLYMOUTH_SCRIPT_DIR}/../plymouth/${PLYMOUTH_THEME}"
    local target_dir="/mnt/usr/share/plymouth/themes/${PLYMOUTH_THEME}"

    if [[ ! -d "${source_dir}" ]]; then
        error "Plymouth theme not found at ${source_dir}"
        return 1
    fi

    install -d -m 755 "${target_dir}"
    install -m 644 "${source_dir}"/* "${target_dir}/"

    if ! add_plymouth_hook; then
        error "Failed to add the plymouth hook to mkinitcpio.conf"
        return 1
    fi

    # -R rebuilds every initramfs, which is what actually carries the theme into
    # early boot; without it the new theme is inert until the next kernel update.
    if ! arch-chroot /mnt plymouth-set-default-theme -R "${PLYMOUTH_THEME}"; then
        error "Failed to set the Plymouth default theme"
        return 1
    fi

    log "Plymouth configured successfully"
}
