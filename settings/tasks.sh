#!/usr/bin/env bash

# Task wrapper functions
# These functions bridge the task execution system with the actual implementation modules
# Each task sources its required dependencies when called

TASKS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

task_check_prerequisites() {
    source "${TASKS_SCRIPT_DIR}/../utils/check-prerequisites.sh"
    check_prerequisites
}

task_update_system_clock() {
    source "${TASKS_SCRIPT_DIR}/../config/system/ntp.sh"
    update_iso_system_clock
}

task_detect_timezone() {
    source "${TASKS_SCRIPT_DIR}/../config/system/timezone.sh"
    detect_timezone
}

task_create_partitions() {
    source "${TASKS_SCRIPT_DIR}/../disk/partitions.sh"
    create_partitions
    detect_partitions
    format_efi_partition
}

task_setup_encryption() {
    source "${TASKS_SCRIPT_DIR}/../disk/luks.sh"
    setup_luks_automated
}

task_setup_lvm() {
    source "${TASKS_SCRIPT_DIR}/../disk/lvm.sh"
    setup_lvm
}

task_format_filesystems() {
    source "${TASKS_SCRIPT_DIR}/../disk/filesystem.sh"
    format_logical_volumes
    create_btrfs_subvolumes
}

task_mount_filesystems() {
    source "${TASKS_SCRIPT_DIR}/../disk/mount.sh"
    mount_filesystems
}

task_install_base_system() {
    source "${TASKS_SCRIPT_DIR}/../packages/base.sh"
    source "${TASKS_SCRIPT_DIR}/../bootloader/configure-refind.sh"
    source "${TASKS_SCRIPT_DIR}/../disk/fstab.sh"
    install_base_system
    setup_pacman_hook
    generate_fstab
}

task_configure_system() {
    source "${TASKS_SCRIPT_DIR}/../config/during-install.sh"
    configure_system_automated
}

task_setup_bootloader() {
    source "${TASKS_SCRIPT_DIR}/../bootloader/configure-refind.sh"
    configure_refind
}

task_create_user() {
    source "${TASKS_SCRIPT_DIR}/../config/system/sudoers.sh"
    source "${TASKS_SCRIPT_DIR}/../config/system/user.sh"
    create_sudoers_config
    add_new_user_automated
    configure_sudoers
}

task_setup_secondary_luks() {
    source "${TASKS_SCRIPT_DIR}/../disk/luks.sh"
    setup_secondary_luks_auto_unlock
}

task_install_official_packages() {
    source "${TASKS_SCRIPT_DIR}/../packages/official.sh"
    install_official_packages
}

task_install_aur_packages() {
    source "${TASKS_SCRIPT_DIR}/../packages/aur.sh"
    install_aur_packages
}

task_install_dev_packages() {
    source "${TASKS_SCRIPT_DIR}/../packages/dev.sh"
    install_development_tools
}

task_install_nvidia_drivers() {
    source "${TASKS_SCRIPT_DIR}/../packages/nvidia.sh"
    install_nvidia_drivers
}

task_configure_mirrors() {
    source "${TASKS_SCRIPT_DIR}/../config/system/pacman.sh"
    configure_mirrors
}

task_configure_system_post_install() {
    source "${TASKS_SCRIPT_DIR}/../config/post-install.sh"
    configure_system_post_install
}
