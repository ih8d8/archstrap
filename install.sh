#!/usr/bin/env bash

set -euo pipefail

# Script directory for sourcing modules
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source essential modules only
source "${SCRIPT_DIR}/utils/colors.sh"
source "${SCRIPT_DIR}/utils/logging.sh"
source "${SCRIPT_DIR}/settings/env.sh"
source "${SCRIPT_DIR}/settings/tasks.sh"
source "${SCRIPT_DIR}/utils/task-handler.sh"
source "${SCRIPT_DIR}/utils/inputs.sh"
source "${SCRIPT_DIR}/utils/cleanup.sh"

# Main installation function
main() {
    # Setup logging first
    setup_logging
    
    # Initialize the task system
    init_tasks
    
    # Show initial task list
    display_task_list
    
    echo -e "${BOLD}${CYAN}Starting Arch Linux Installation...${NC}"
    echo -e "${CYAN}This will install Arch Linux with LUKS encryption and LVM${NC}"
    echo
    sleep 1
    
    # Collect all user inputs first
    collect_user_inputs
    
    # Execute tasks with visual progress
    if ! execute_task "check_prerequisites" "task_check_prerequisites"; then
        handle_task_failure "Prerequisites check failed. Exiting."
    fi
    
    # These tasks must run sequentially
    if ! execute_task "update_system_clock" "task_update_system_clock"; then
        handle_task_failure "System clock update failed. Exiting."
    fi
    if ! execute_task "detect_timezone" "task_detect_timezone"; then
        handle_task_failure "Timezone detection failed. Exiting."
    fi
    if ! execute_task "create_partitions" "task_create_partitions"; then
        handle_task_failure "Partition creation failed. Exiting."
    fi
    if ! execute_task "setup_encryption" "task_setup_encryption"; then
        handle_task_failure "Disk encryption setup failed. Exiting."
    fi
    if ! execute_task "setup_lvm" "task_setup_lvm"; then
        handle_task_failure "LVM setup failed. Exiting."
    fi
    if ! execute_task "format_filesystems" "task_format_filesystems"; then
        handle_task_failure "Filesystem formatting failed. Exiting."
    fi
    if ! execute_task "mount_filesystems" "task_mount_filesystems"; then
        handle_task_failure "Filesystem mounting failed. Exiting."
    fi
    if ! execute_task "install_base_system" "task_install_base_system"; then
        handle_task_failure "Base system installation failed. Exiting."
    fi
    if ! execute_task "configure_system" "task_configure_system"; then
        handle_task_failure "System configuration failed. Exiting."
    fi
    if ! execute_task "setup_bootloader" "task_setup_bootloader"; then
        handle_task_failure "Bootloader setup failed. Exiting."
    fi
    if ! execute_task "create_user" "task_create_user"; then
        handle_task_failure "User creation failed. Exiting."
    fi
    if ! execute_task "setup_secondary_luks" "task_setup_secondary_luks"; then
        handle_task_failure "Secondary LUKS setup failed. Exiting."
    fi

    if ! execute_task "install_official_packages" "task_install_official_packages"; then
        handle_task_failure "Official package installation failed. Exiting."
    fi

    if ! execute_task "install_aur_packages" "task_install_aur_packages"; then
        handle_task_failure "AUR package installation failed. Exiting."
    fi

    if ! execute_task "install_dev_packages" "task_install_dev_packages"; then
        handle_task_failure "Development package installation failed. Exiting."
    fi

    if ! execute_task "install_nvidia_drivers" "task_install_nvidia_drivers"; then
        handle_task_failure "NVIDIA driver installation failed. Exiting."
    fi

    if ! execute_task "configure_mirrors" "task_configure_mirrors"; then
        handle_task_failure "Mirror configuration failed. Exiting."
    fi

    if ! execute_task "configure_system_post_install" "task_configure_system_post_install"; then
        handle_task_failure "System post-installation configuration failed. Exiting."
    fi
    
    # Final status
    echo
    if [[ ${FAILED_TASKS} -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}🎉 Arch Linux installation completed successfully!${NC}"
        echo -e "${GREEN}All tasks completed without errors.${NC}"
        echo
        echo -e "${CYAN}Your encrypted Arch Linux system is ready!${NC}"
        echo -e "${CYAN}Please reboot and enter your LUKS password when prompted.${NC}"
        cleanup 0 true # Force cleanup on successful exit
        exit 0 # Explicitly exit with 0 on success
    else
        echo -e "${BOLD}${RED}❌ Installation failed with ${FAILED_TASKS} error(s).${NC}"
        display_error_summary
        echo -e "${RED}Please resolve the issues above before attempting to boot the system.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
