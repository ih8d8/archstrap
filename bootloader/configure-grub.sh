#!/usr/bin/env bash

GRUB_CONFIG_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${GRUB_CONFIG_SCRIPT_DIR}/../utils/logging.sh"
fi

grub_kernel_options() {
    local filesystem="${FILESYSTEM_FORMAT:-ext4}"
    local root_device
    local blk_options

    if [[ "${LVM_CREATED:-true}" == "true" ]]; then
        root_device="/dev/vg1/root"
    else
        root_device="/dev/mapper/luks"
    fi

    if grep -q '^HOOKS=.*systemd' /mnt/etc/mkinitcpio.conf; then
        blk_options="rd.luks.name=${LUKS_UUID}=luks root=${root_device}"
    else
        blk_options="cryptdevice=UUID=${LUKS_UUID}:luks root=${root_device}"
    fi

    if [[ "${filesystem}" == "btrfs" ]]; then
        blk_options="${blk_options} rootflags=subvol=@"
    fi

    # quiet/splash and the lowered log levels exist to keep the console clear for
    # Plymouth; verbose boot output would scroll over the splash and the LUKS
    # prompt. Drop `quiet splash` to get the old text boot back.
    printf '%s rw quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0' "${blk_options}"
}

set_grub_default() {
    local key="${1}"
    local value="${2}"
    local file="/mnt/etc/default/grub"

    if grep -q "^${key}=" "${file}"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "${file}"
    else
        printf '%s="%s"\n' "${key}" "${value}" >> "${file}"
    fi
}

configure_grub() {
    log "Configuring GRUB bootloader..."

    set_grub_default "GRUB_CMDLINE_LINUX" "$(grub_kernel_options)"
    set_grub_default "GRUB_DISABLE_OS_PROBER" "false"
    set_grub_default "GRUB_DISABLE_SUBMENU" "y"
    set_grub_default "GRUB_TOP_LEVEL" "/boot/vmlinuz-linux"
    set_grub_default "GRUB_DEFAULT" "0"
    set_grub_default "GRUB_SAVEDEFAULT" "false"
    # Shown, not hidden: snapshot entries live in a generated grub-btrfs.cfg
    # whose titles rotate as snapper prunes, so grub-reboot cannot target them
    # and the interactive menu is the only route back to a snapshot. Three
    # seconds is long enough to choose one without waiting on every boot.
    set_grub_default "GRUB_TIMEOUT_STYLE" "menu"
    set_grub_default "GRUB_TIMEOUT" "3"
    set_grub_default "GRUB_GFXMODE" "auto"
    set_grub_default "GRUB_GFXPAYLOAD_LINUX" "keep"
    set_grub_default "GRUB_TERMINAL_OUTPUT" "gfxterm"
    set_grub_default "GRUB_COLOR_NORMAL" "light-gray/black"
    set_grub_default "GRUB_COLOR_HIGHLIGHT" "black/magenta"

    if [[ "${FILESYSTEM_FORMAT:-ext4}" == "btrfs" ]]; then
        setup_grub_btrfs
    fi

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    log "GRUB configured successfully"
}

setup_grub_btrfs() {
    log "Configuring grub-btrfs integration..."

    if [[ -f /mnt/etc/default/grub-btrfs/config ]]; then
        set_grub_btrfs_default "GRUB_BTRFS_GRUB_DIRNAME" "/boot/grub"
        set_grub_btrfs_default "GRUB_BTRFS_SUBMENUNAME" "Arch Linux snapshots"
    fi

    if [[ -f /mnt/etc/grub.d/41_snapshots-btrfs ]]; then
        chmod +x /mnt/etc/grub.d/41_snapshots-btrfs
    else
        warning "grub-btrfs generator not found at /etc/grub.d/41_snapshots-btrfs"
    fi

}

set_grub_btrfs_default() {
    local key="${1}"
    local value="${2}"
    local file="/mnt/etc/default/grub-btrfs/config"

    if grep -q "^#\?${key}=" "${file}"; then
        sed -i "s|^#\?${key}=.*|${key}=\"${value}\"|" "${file}"
    else
        printf '%s="%s"\n' "${key}" "${value}" >> "${file}"
    fi
}
