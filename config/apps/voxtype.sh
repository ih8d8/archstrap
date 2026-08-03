#!/usr/bin/env bash

# Source required utilities
VOXTYPE_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${VOXTYPE_SCRIPT_DIR}/../../utils/logging.sh"
fi

# base.en is the balance point: 142MB, and English-only is both faster and more
# accurate than the multilingual build of the same size.
VOXTYPE_MODEL="${VOXTYPE_MODEL:-base.en}"

# Download the voxtype transcription model.
#
# The only piece dotfiles cannot carry: config.toml is stowed, and the service
# is enabled by the tracked graphical-session.target.wants symlink. This is a
# 142MB binary blob that has no business in a git repo.
configure_voxtype() {
    log "Configuring voxtype..."

    if ! arch-chroot /mnt which voxtype &>/dev/null; then
        warning "voxtype is not installed, skipping configuration"
        return 0
    fi

    log "Downloading voxtype model (${VOXTYPE_MODEL})..."

    # --quiet and --no-post-install keep it non-interactive; without --model the
    # selection is a menu that would block the install.
    if ! arch-chroot /mnt sudo -u "${NEW_USER}" \
        voxtype setup --download --model "${VOXTYPE_MODEL}" --quiet --no-post-install; then
        warning "Failed to download voxtype model, run 'voxtype setup model' after first login"
        return 0
    fi

    # The Quickshell OSD frontend named in config.toml needs its QML tree; it
    # lands in ~/.local/share, so it is generated rather than tracked.
    arch-chroot /mnt sudo -u "${NEW_USER}" voxtype setup quickshell &>/dev/null \
        || warning "Failed to install voxtype Quickshell OSD, run 'voxtype setup quickshell'"

    log "voxtype model downloaded"
}
