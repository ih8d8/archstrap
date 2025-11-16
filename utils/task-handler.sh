#!/usr/bin/env bash

# Source required utilities
if [[ -z "${GREEN:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [[ -z "${LOG_FILE:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Task tracking variables
declare -A TASK_STATUS
declare -A TASK_ERRORS
declare -a TASK_LIST
declare -a TASK_DESCRIPTIONS
TOTAL_TASKS=0
COMPLETED_TASKS=0
FAILED_TASKS=0

# Initialize task tracking
init_tasks() {
    TASK_LIST=(
        "check_prerequisites"
        "update_system_clock"
        "detect_timezone"
        "create_partitions"
        "setup_encryption"
        "setup_lvm"
        "format_filesystems"
        "mount_filesystems"
        "install_base_system"
        "configure_system"
        "setup_bootloader"
        "create_user"
        "setup_secondary_luks"
        "install_official_packages"
        "install_aur_packages"
        "install_dev_packages"
        "install_nvidia_drivers"
        "configure_mirrors"
        "configure_system_post_install"
    )
    
    TASK_DESCRIPTIONS=(
        "Checking system prerequisites"
        "Updating system clock"
        "Detecting timezone"
        "Creating disk partitions"
        "Setting up disk encryption"
        "Configuring LVM volumes"
        "Formatting filesystems"
        "Mounting filesystems"
        "Installing base system"
        "Configuring system settings"
        "Setting up bootloader"
        "Creating user account"
        "Setting up secondary LUKS storage"
        "Installing official packages"
        "Installing AUR packages"
        "Installing development packages"
        "Installing NVIDIA drivers"
        "Configuring fastest mirrors"
        "Configuring system post-installation"
    )
    
    TOTAL_TASKS=${#TASK_LIST[@]}
    
    # Initialize all tasks as pending
    for task in "${TASK_LIST[@]}"; do
        TASK_STATUS[$task]="pending"
    done
}

# Display the task list with current status
display_task_list() {
    clear
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                         ARCH LINUX INSTALLER                  ║${NC}"
    echo -e "${BOLD}${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    if [ "$COMPLETED_TASKS" -lt 10 ]; then
    # This version has one extra space before the final "║" to align the output
    echo -e "${BOLD}${CYAN}║ Progress: ${WHITE}${COMPLETED_TASKS}${CYAN}/${WHITE}${TOTAL_TASKS}${CYAN} completed, ${RED}${FAILED_TASKS}${CYAN} failed                            ║${NC}"
    else
    # This is the original line for numbers >= 10
    echo -e "${BOLD}${CYAN}║ Progress: ${WHITE}${COMPLETED_TASKS}${CYAN}/${WHITE}${TOTAL_TASKS}${CYAN} completed, ${RED}${FAILED_TASKS}${CYAN} failed                           ║${NC}"
    fi
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    for i in "${!TASK_LIST[@]}"; do
        local task="${TASK_LIST[$i]}"
        local description="${TASK_DESCRIPTIONS[$i]}"
        local status="${TASK_STATUS[$task]}"
        local symbol=""
        local color=""
        
        case ${status} in
            "pending")
                symbol="${PENDING_MARK}"
                color="${WHITE}"
                ;;
            "running")
                symbol="${PROGRESS_MARK}"
                color="${YELLOW}"
                ;;
            "completed")
                symbol="${CHECK_MARK}"
                color="${GREEN}"
                ;;
            "failed")
                symbol="${ERROR_MARK}"
                color="${RED}"
                ;;
        esac
        
        printf "${color}[%s]${NC} %s\n" "${symbol}" "${description}"
    done
    echo
}

# Update task status and refresh display
update_task_status() {
    local task="$1"
    local status="$2"
    
    TASK_STATUS[$task]="${status}"
    
    case ${status} in
        "completed")
            ((COMPLETED_TASKS++))
            ;;
        "failed")
            ((FAILED_TASKS++))
            ;;
    esac
    
    display_task_list
}

# Execute a task with status tracking and error capture
execute_task() {
    local task="$1"
    local func="$2"
    shift 2
    
    update_task_status "${task}" "running"
    
    log "Starting task: ${task}"
    log "Running function: ${func}"
    
    # Store the current task in a global variable for trap handling
    export CURRENT_RUNNING_TASK="${task}"
    
    # Temporarily disable set -e to prevent immediate exit on error
    set +e
    ${func} "$@"
    local exit_code=$?
    # Clear the current running task before re-enabling set -e
    unset CURRENT_RUNNING_TASK
    # Re-enable set -e
    set -e
    
    if [[ ${exit_code} -eq 0 ]]; then
        log "Task completed successfully: ${task}"
        update_task_status "${task}" "completed"
        return 0
    else
        log "Task failed with exit code ${exit_code}: ${task}"
        TASK_ERRORS[$task]="Exit code: ${exit_code} - Function failed during execution"
        update_task_status "${task}" "failed"
        return 1
    fi
}

# Display error summary
display_error_summary() {
    if [[ ${FAILED_TASKS} -gt 0 ]]; then
        echo # Keep this echo for a blank line
        echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║                        ERROR SUMMARY                          ║${NC}"
        echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo
        
        for i in "${!TASK_LIST[@]}"; do
            local task="${TASK_LIST[$i]}"
            local description="${TASK_DESCRIPTIONS[$i]}"
            local status="${TASK_STATUS[$task]}"
            
            if [[ "${status}" == "failed" ]]; then
                echo -e "${RED}[✗] ${description}${NC}"
                if [[ -n "${TASK_ERRORS[$task]:-}" ]]; then
                    echo -e "${YELLOW}    Error: ${TASK_ERRORS[$task]}${NC}"
                fi
                echo
            fi
        done
        
        echo -e "${RED}[ERROR]${NC} Installation failed with ${FAILED_TASKS} error(s). Please review the issues above."
        echo
    fi
}

# Helper function to handle task failures with proper error display
handle_task_failure() {
    local error_message="$1"
    display_task_list
    display_error_summary
    fatal_error "$error_message"
}