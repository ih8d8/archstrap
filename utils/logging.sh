#!/usr/bin/env bash

# Source colors if not already loaded
if [[ -z "${GREEN:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Global variable for log file
LOG_FILE=""

# Enhanced logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    # Return a non-zero status to trigger the ERR trap for cleanup and exit
    return 1
}

# Fatal error function that exits immediately without triggering traps
fatal_error() {
    echo -e "${RED}[FATAL ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Setup logging to a file and stdout/stderr
setup_logging() {
    LOG_FILE="/var/log/arch-install-$(date +%Y%m%d-%H%M%S).log"
    
    # Ensure /var/log exists and is writable
    if [[ ! -d "/var/log" ]]; then
        mkdir -p "/var/log" || { echo "ERROR: Could not create /var/log. Logging to current directory." >&2; LOG_FILE="./arch-install-$(date +%Y%m%d-%H%M%S).log"; }
    fi

    # Save original stdout and stderr
    exec 3>&1 4>&2

    # Redirect stdout and stderr to log file and tee to original stdout/stderr
    # This ensures all output goes to the log file AND the terminal
    exec > >(tee -a "${LOG_FILE}" >&3) 2> >(tee -a "${LOG_FILE}" >&4)
    
    log "All script output is being logged to: ${LOG_FILE}"
}