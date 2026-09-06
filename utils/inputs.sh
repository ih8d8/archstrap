#!/usr/bin/env bash

# Source required utilities
INPUTS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${GREEN:-}" ]]; then
    source "${INPUTS_SCRIPT_DIR}/colors.sh"
fi
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${INPUTS_SCRIPT_DIR}/logging.sh"
fi

# Source private environment variables if available
# This allows pre-setting HOSTNAME, NEW_USER, SECONDARY_LANGUAGE, etc.
if [[ -f "${INPUTS_SCRIPT_DIR}/../settings/env-private.sh" ]]; then
    source "${INPUTS_SCRIPT_DIR}/../settings/env-private.sh"
fi

# Collect all user inputs at the beginning
collect_user_inputs() {
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    INSTALLATION SETUP                         ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Please provide the following information for automated installation:${NC}"
    echo

    # Get hostname (skip if already set in env-private.sh)
    if [[ -n "${HOSTNAME:-}" ]]; then
        log "Using pre-configured hostname: ${HOSTNAME}"
    else
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
    fi
    
    # Get username (skip if already set in env-private.sh)
    if [[ -n "${NEW_USER:-}" ]]; then
        log "Using pre-configured username: ${NEW_USER}"
    else
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
    fi
    
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

    # Select bootloader (skip if already set in env-private.sh)
    if [[ -n "${BOOTLOADER:-}" ]]; then
        [[ "${BOOTLOADER}" == "grub" || "${BOOTLOADER}" == "refind" ]] ||
            fatal_error "Unsupported bootloader: ${BOOTLOADER}. Use grub or refind."
        log "Using pre-configured bootloader: ${BOOTLOADER}"
    else
        echo
        echo -e "${YELLOW}Bootloader Selection${NC}"
        echo "Choose the bootloader for your system:"
        echo "  1) GRUB (default, recommended for Btrfs snapshots)"
        echo "  2) rEFInd"
        echo

        while true; do
            read -rp "Enter your choice (1-2, default 1): " bootloader_choice
            echo
            case "${bootloader_choice:-1}" in
                1)
                    BOOTLOADER="grub"
                    log "Selected GRUB bootloader"
                    break
                    ;;
                2)
                    BOOTLOADER="refind"
                    log "Selected rEFInd bootloader"
                    break
                    ;;
                *)
                    warning "Invalid choice. Please enter 1 for GRUB or 2 for rEFInd"
                    ;;
            esac
        done
    fi
    
    # Select secondary language (skip if already set in env-private.sh)
    if [[ -n "${SECONDARY_LANGUAGE:-}" ]]; then
        log "Using pre-configured secondary language: ${SECONDARY_LANGUAGE}"
    else
        select_secondary_language
    fi
    
    # Dotfiles repository selection
    echo
    echo -e "${YELLOW}Dotfiles Configuration${NC}"
    
    # Check if private dotfiles repository is configured
    if [[ -n "${PRIVATE_DOTFILES_REPO:-}" ]]; then
        echo "Choose which dotfiles repository to use:"
        echo "  1) Public repository: ${PUBLIC_DOTFILES_REPO}"
        echo "  2) Private repository: ${PRIVATE_DOTFILES_REPO}"
        echo
        
        while true; do
            read -rp "Enter your choice (1-2): " dotfiles_choice
            echo
            case "$dotfiles_choice" in
                1)
                    SELECTED_DOTFILES_REPO="${PUBLIC_DOTFILES_REPO}"
                    log "Will use public dotfiles from: ${SELECTED_DOTFILES_REPO}"
                    break
                    ;;
                2)
                    SELECTED_DOTFILES_REPO="${PRIVATE_DOTFILES_REPO}"
                    log "Will use private dotfiles from: ${SELECTED_DOTFILES_REPO}"
                    break
                    ;;
                *)
                    warning "Invalid choice. Please enter 1 or 2"
                    ;;
            esac
        done
    else
        # Only public repository available
        SELECTED_DOTFILES_REPO="${PUBLIC_DOTFILES_REPO}"
        log "Using public dotfiles from: ${SELECTED_DOTFILES_REPO}"
    fi
    
    # Setup dotfiles
    setup_dotfiles
    
    echo
    log "Configuration completed. Starting automated installation..."
    echo
    sleep 2
}

# Select secondary language using dialog (ncurses interface)
# Sets SECONDARY_LANGUAGE variable (empty for English only)
# Dynamically reads available locales from /etc/locale.gen
select_secondary_language() {
    echo
    echo -e "${YELLOW}Secondary Language Selection${NC}"
    echo "You can optionally enable a secondary language locale besides English."
    echo
    
    # Source locale.gen file - use /mnt/etc/locale.gen if available (during install), else /etc/locale.gen
    local locale_gen_file="/etc/locale.gen"
    if [[ -f "/mnt/etc/locale.gen" ]]; then
        locale_gen_file="/mnt/etc/locale.gen"
    fi
    
    # Build array of available UTF-8 locales from locale.gen
    # Format for dialog: "tag" "description" pairs
    local dialog_items=()
    dialog_items+=("" "None (English only)")
    
    # Extract UTF-8 locales, excluding en_US which is always enabled
    # Pattern: match lines starting with # that have UTF-8 as the charset (second column)
    while IFS= read -r line; do
        # Extract locale code (first column after removing #)
        local locale_code
        locale_code=$(echo "$line" | sed 's/^#//' | awk '{print $1}')
        
        # Skip en_US locales as English is always enabled
        if [[ "$locale_code" == en_US* ]]; then
            continue
        fi
        
        # Add to dialog items (locale code as both tag and description for simplicity)
        dialog_items+=("$locale_code" "$locale_code")
    done < <(grep "^#.* UTF-8" "$locale_gen_file" | grep -v "@" | sort)
    
    # Use dialog for ncurses menu selection
    # Default selection is empty (None/English only)
    local result
    result=$(dialog --clear --title "Secondary Language Selection" \
        --default-item "" \
        --menu "Select a secondary language to enable besides English (US).\nPress Enter to select, or choose 'None' for English only.\n\nUse arrow keys to navigate, type to search." \
        22 70 14 \
        "${dialog_items[@]}" \
        2>&1 >/dev/tty)
    
    local dialog_exit_code=$?
    
    # Clear the dialog screen
    clear 2>/dev/null || true
    
    # Handle dialog exit (cancel or ESC pressed)
    if [[ $dialog_exit_code -ne 0 ]]; then
        log "No secondary language selected (dialog cancelled)"
        SECONDARY_LANGUAGE=""
        return
    fi
    
    # Set the selected language
    SECONDARY_LANGUAGE="${result}"
    
    if [[ -n "${SECONDARY_LANGUAGE}" ]]; then
        log "Selected secondary language: ${SECONDARY_LANGUAGE}"
    else
        log "No secondary language selected - English only"
    fi
}

# Setup dotfiles by cloning selected repository
# This function clears the config/dotfiles directory and clones the selected repository
setup_dotfiles() {
    if [[ -z "${SELECTED_DOTFILES_REPO:-}" ]]; then
        log "No dotfiles repository selected, skipping dotfiles setup"
        return 0
    fi
    
    local dotfiles_dir="${INPUTS_SCRIPT_DIR}/../config/dotfiles"
    
    log "Setting up dotfiles from ${SELECTED_DOTFILES_REPO}"
    
    # Remove all files from config/dotfiles directory (including .gitignore)
    if [[ -d "${dotfiles_dir}" ]]; then
        log "Cleaning existing dotfiles directory: ${dotfiles_dir}"
        rm -rf "${dotfiles_dir}"
    fi
    
    # Clone the selected dotfiles repository into config/dotfiles
    log "Cloning dotfiles repository..."
    if git clone "${SELECTED_DOTFILES_REPO}" "${dotfiles_dir}"; then
        log "Successfully cloned dotfiles to ${dotfiles_dir}"
    else
        fatal_error "Failed to clone dotfiles repository: ${SELECTED_DOTFILES_REPO}"
    fi
}
