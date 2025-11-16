#!/usr/bin/env bash

# Global variables for Arch Linux installation
export BLOCK_DEVICE=""
export SECONDARY_BLOCK_DEVICE=""
export BOOT_PARTITION=""
export LUKS_PARTITION=""
export LUKS_UUID=""
export HOSTNAME=""
export TIME_ZONE=""
export NEW_USER=""
export USER_PASSWORD=""
export ROOT_PASSWORD=""
export LUKS_PASSWORD=""

# Installation state tracking
export LUKS_OPENED=false
export SECONDARY_LUKS_OPENED=false
export LVM_CREATED=false
export FILESYSTEMS_MOUNTED=false
export CLEANUP_NEEDED=false
