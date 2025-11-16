#!/usr/bin/env bash

# Source required utilities
INPUTS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${GREEN:-}" ]]; then
    source "${INPUTS_SCRIPT_DIR}/colors.sh"
fi
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${INPUTS_SCRIPT_DIR}/logging.sh"
fi

# Collect all user inputs at the beginning
collect_user_inputs() {
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    INSTALLATION SETUP                         ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Please provide the following information for automated installation:${NC}"
    echo

    # Get hostname
    while true; do
        printf "Enter hostname: "
        read -r HOSTNAME
        if [[ -n "${HOSTNAME}" ]] && [[ "${HOSTNAME}" =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            warning "Invalid hostname. Use only letters, numbers, and hyphens."
            printf "\\n" # Add newline after warning if it's printed
        fi
    done
    
    # Get username
    while true; do
        printf "Enter username for new user: "
        read -r NEW_USER
        if [[ -n "${NEW_USER}" ]] && [[ "${NEW_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        else
            warning "Invalid username. Use only lowercase letters, numbers, underscores, and hyphens. Must start with letter or underscore."
            printf "\\n" # Add newline after warning if it's printed
        fi
    done
    
    # Get user password
    while true; do
        printf "Enter password for user %s: " "${NEW_USER}"
        read -r -s USER_PASSWORD
        printf "\\n" # Ensure newline after silent input
        printf "Confirm password: "
        read -r -s confirm_password
        printf "\\n" # Ensure newline after silent input
        if [[ "${USER_PASSWORD}" == "${confirm_password}" ]] && [[ -n "${USER_PASSWORD}" ]]; then
            break
        else
            warning "Passwords don't match or are empty. Please try again."
            printf "\\n" # Add newline after warning if it's printed
        fi
    done
    
    # Get root password
    while true; do
        printf "Enter root password: "
        read -r -s ROOT_PASSWORD
        printf "\\n" # Ensure newline after silent input
        printf "Confirm root password: "
        read -r -s confirm_password
        printf "\\n" # Ensure newline after silent input
        if [[ "${ROOT_PASSWORD}" == "${confirm_password}" ]] && [[ -n "${ROOT_PASSWORD}" ]]; then
            break
        else
            warning "Passwords don't match or are empty. Please try again."
            printf "\\n" # Add newline after warning if it's printed
        fi
    done
    
    # Get LUKS password
    while true; do
        printf "Enter LUKS encryption password: "
        read -r -s LUKS_PASSWORD
        printf "\\n" # Ensure newline after silent input
        printf "Confirm LUKS password: "
        read -r -s confirm_password
        printf "\\n" # Ensure newline after silent input
        if [[ "${LUKS_PASSWORD}" == "${confirm_password}" ]] && [[ -n "${LUKS_PASSWORD}" ]]; then
            break
        else
            warning "Passwords do not match or are empty. Please try again."
            printf "\\n" # Add newline after warning if it's printed
        fi
    done
    
    # Select block device
    echo
    log "Available block devices:"
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "(disk|nvme)"
    echo
    
    mapfile -t devices < <(lsblk -d -n -o NAME | grep -E "^(sd|nvme|vd|mmcblk)")
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        fatal_error "No suitable block devices found! Please ensure you are running this script on a system with available block devices (e.g., /dev/sda, /dev/nvme0n1, /dev/mmcblk0)."
    fi
    
    echo "Select a device to install Arch Linux:"
    for i in "${!devices[@]}"; do
        echo "  $((i+1))) /dev/${devices[$i]}"
    done
    echo
    
    while true; do
        read -r -p "Enter your choice (1-${#devices[@]}): " choice
        echo # Add newline after input
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [[ "${choice}" -ge 1 ]] && [[ "${choice}" -le ${#devices[@]} ]]; then
            BLOCK_DEVICE="/dev/${devices[$((choice-1))]}"
            break
        else
            warning "Invalid choice. Please enter a number between 1 and ${#devices[@]}"
        fi
    done
    
    # Confirm selection
    warning "You selected: ${BLOCK_DEVICE}"
    warning "ALL DATA ON THIS DEVICE WILL BE DESTROYED!"
    echo
    read -r -p "Are you sure you want to continue? (y/n): " confirm
    echo # Add newline after confirmation
    
    if [[ "$confirm" != "y" ]]; then
        fatal_error "Installation cancelled by user"
    fi
    
    # Check if there are other block devices available for secondary storage
    mapfile -t available_secondary_devices < <(lsblk -d -n -o NAME | grep -E "^(sd|nvme|vd|mmcblk)" | while read -r device; do
        if [[ "/dev/$device" != "${BLOCK_DEVICE}" ]]; then
            echo "$device"
        fi
    done)
    
    # Only show secondary storage options if there are additional devices available
    if [[ ${#available_secondary_devices[@]} -gt 0 ]]; then
        # Select secondary block device for additional LUKS storage (optional)
        echo
        echo -e "${YELLOW}Secondary Storage Setup (Optional)${NC}"
        echo "You can set up an additional encrypted drive that will auto-unlock after the main drive."
        echo
        read -rp "Do you want to set up a secondary encrypted drive? (y/n): " setup_secondary
        echo
        
        if [[ "$setup_secondary" == "y" ]]; then
            echo "Available devices for secondary storage (excluding primary ${BLOCK_DEVICE}):"
            
            # Show available secondary devices with details
            for device in "${available_secondary_devices[@]}"; do
                size=$(lsblk -ndo SIZE "/dev/$device")
                model=$(lsblk -ndo MODEL "/dev/$device" | xargs)
                echo "  /dev/$device - $size ${model:+($model)}"
            done
            echo
            
            echo "Select a device for secondary encrypted storage:"
            for i in "${!available_secondary_devices[@]}"; do
                echo "  $((i+1))) /dev/${available_secondary_devices[$i]}"
            done
            echo
            
            while true; do
                read -rp "Enter your choice (1-${#available_secondary_devices[@]}): " sec_choice
                echo
                if [[ "${sec_choice}" =~ ^[0-9]+$ ]] && [[ "${sec_choice}" -ge 1 ]] && [[ "${sec_choice}" -le ${#available_secondary_devices[@]} ]]; then
                    SECONDARY_BLOCK_DEVICE="/dev/${available_secondary_devices[$((sec_choice-1))]}"
                    break
                else
                    warning "Invalid choice. Please enter a number between 1 and ${#available_secondary_devices[@]}"
                fi
            done
            
            # Confirm secondary selection
            warning "You selected: ${SECONDARY_BLOCK_DEVICE}"
            warning "ALL DATA ON THIS DEVICE WILL BE DESTROYED!"
            echo
            read -rp "Are you sure you want to use this device for secondary storage? (y/n): " sec_confirm
            echo
            
            if [[ "$sec_confirm" != "y" ]]; then
                log "Secondary storage setup cancelled."
                SECONDARY_BLOCK_DEVICE=""
            fi
        else
            SECONDARY_BLOCK_DEVICE=""
        fi
    else
        # No additional devices available, skip secondary storage setup
        SECONDARY_BLOCK_DEVICE=""
    fi
    
    # Select filesystem format
    echo
    echo -e "${YELLOW}Filesystem Format Selection${NC}"
    echo "Choose the filesystem format for your system:"
    echo "  1) ext4 (recommended for stability)"
    echo "  2) btrfs (advanced features, snapshots)"
    echo
    
    while true; do
        read -rp "Enter your choice (1-2): " fs_choice
        echo
        case "$fs_choice" in
            1)
                FILESYSTEM_FORMAT="ext4"
                log "Selected ext4 filesystem format"
                break
                ;;
            2)
                FILESYSTEM_FORMAT="btrfs"
                log "Selected btrfs filesystem format"
                break
                ;;
            *)
                warning "Invalid choice. Please enter 1 for ext4 or 2 for btrfs"
                ;;
        esac
    done
    
    echo
    log "Configuration completed. Starting automated installation..."
    echo
    sleep 2
}