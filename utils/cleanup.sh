#!/usr/bin/env bash

# Source required utilities
if [[ -z "${GREEN:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [[ -z "${LOG_FILE:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Source unmount utilities
source "$(dirname "${BASH_SOURCE[0]}")/../disk/unmount.sh"

# Unified cleanup function
cleanup() {
    local exit_code="${1:-0}" # Default to 0 if no argument is provided
    local force="${2:-false}" # Default to false if no argument is provided
    
    # Only cleanup if needed or if force is true
    if [[ "${CLEANUP_NEEDED}" == false ]] && [[ "${force}" == "false" ]]; then
        return 0
    fi
    
    # Determine if cleanup is due to an error or normal exit
    if [[ "${exit_code}" -ne 0 ]]; then
        echo
        echo -e "${RED}[ERROR]${NC} Script failed with exit code: ${exit_code}"
        warning "Performing cleanup..."
    else
        log "Cleaning up and unmounting filesystems..."
    fi
    
    # Unmount filesystems if they were mounted or if force is true
    if [[ "${FILESYSTEMS_MOUNTED}" == true ]] || [[ "${force}" == "true" ]]; then
        # Kill any processes that might be using the mount points (only on error)
        if [[ "${exit_code}" -ne 0 ]]; then
            fuser -km /mnt 2>/dev/null || true
            sleep 2
        fi
        
        # Use the dedicated unmount function
        unmount_filesystems
    fi
    
    # Deactivate LVM volumes if they were created or if force is true
    if [[ "${LVM_CREATED}" == true ]] || [[ "${force}" == "true" ]]; then
        log "Deactivating LVM volumes..."
        
        # Deactivate logical volumes to allow LUKS close
        lvchange -an /dev/vg1/home 2>/dev/null || true
        lvchange -an /dev/vg1/root 2>/dev/null || true
        
        # Deactivate volume group
        vgchange -an vg1 2>/dev/null || true
    fi
    
    # Close LUKS container if it was opened or if force is true
    if [[ "${LUKS_OPENED}" == true ]] || [[ "${force}" == "true" ]]; then
        log "Closing LUKS container..."
        
        # Wait a moment for LVM deactivation to complete
        sleep 1
        
        # Make sure device mapper is flushed
        dmsetup info luks >/dev/null 2>&1 && {
            # Try normal close first
            cryptsetup close luks 2>/dev/null || {
                warning "Failed to close LUKS container normally..."
                
                # Force remove any remaining device mappings
                dmsetup remove --force luks 2>/dev/null || {
                    warning "Force remove also failed, trying suspend and remove..."
                    dmsetup suspend luks 2>/dev/null || true
                    dmsetup remove luks 2>/dev/null || warning "All LUKS close attempts failed"
                }
            }
        }
        LUKS_OPENED=false
    fi
    
    # Close secondary LUKS container if it was opened or if force is true
    if [[ "${SECONDARY_LUKS_OPENED:-false}" == true ]] || [[ "${force}" == "true" ]]; then
        log "Closing secondary LUKS container..."
        
        # Close secondary LUKS device (luks2)
        dmsetup info luks2 >/dev/null 2>&1 && {
            # Try normal close first
            cryptsetup close luks2 2>/dev/null || {
                warning "Failed to close secondary LUKS container normally..."
                
                # Force remove any remaining device mappings
                dmsetup remove --force luks2 2>/dev/null || {
                    warning "Force remove also failed, trying suspend and remove..."
                    dmsetup suspend luks2 2>/dev/null || true
                    dmsetup remove luks2 2>/dev/null || warning "All secondary LUKS close attempts failed"
                }
            }
        }
        export SECONDARY_LUKS_OPENED=false
    fi
    
    if [[ "${exit_code}" -ne 0 ]]; then
        warning "Cleanup completed. You may need to manually verify the state of your disks."
        display_error_summary
        exit ${exit_code}
    fi
}

# Enhanced trap to handle display cleanup and unified cleanup
cleanup_on_exit_or_interrupt() {
    local exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then
        echo -e "\\n${RED}Installation interrupted or failed.${NC}"
        
        # Handle tasks that are still in "running" state due to set -e errors
        if [[ -n "${CURRENT_RUNNING_TASK:-}" ]]; then
            log "Task '${CURRENT_RUNNING_TASK}' was interrupted by set -e, marking as failed"
            TASK_ERRORS["${CURRENT_RUNNING_TASK}"]="Exit code: ${exit_code} - Task interrupted by set -e before completion"
            update_task_status "${CURRENT_RUNNING_TASK}" "failed"
            unset CURRENT_RUNNING_TASK
        fi
        
        display_task_list
        display_error_summary
    fi
    cleanup "${exit_code}" # Pass the exit code to cleanup
    exit "${exit_code}"
}

# Set traps for cleanup
trap 'cleanup_on_exit_or_interrupt' EXIT INT TERM
