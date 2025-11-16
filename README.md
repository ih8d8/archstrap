# Archstrap - Modular Arch Linux Installation System

A comprehensive, modular Arch Linux installation system that automates the setup of an encrypted system with flexible filesystem options and extensive package management capabilities.

## Overview

Archstrap provides a fully automated Arch Linux installation experience with LUKS encryption and comprehensive package management. The system supports both ext4 and btrfs filesystems with optional LVM, and uses the rEFInd bootloader for secure boot management.

## Quick Start

Boot from an Arch Linux ISO and run:

```bash
# Connect to internet (if not already connected)
iwctl  # for wireless, or use ethernet

# Clone the repository
git clone https://github.com/ih8d8/archstrap.git
cd archstrap

# Make the installer executable
chmod +x install.sh

# Run the installation
./install.sh
```

The installer will guide you through:
1. System prerequisites validation
2. Timezone detection
3. Disk and filesystem configuration
4. User account setup
5. Package selection confirmation
6. Automated installation and configuration

## Key Features

### 🔐 Security-First Design
- **Full disk encryption** with LUKS
- **Dual LUKS setup** for primary and secondary storage
- **Automated key management** secondary storage (if exists) is automatically unlocked after the primary storage is unlocked
- **Firewall configuration** with UFW

### 🏗️ Modular Architecture
- **Separation of concerns** - Each component handles specific functionality
- **Error handling** - Comprehensive error checking and recovery
- **Progress tracking** - Visual task progress with detailed status
- **Logging system** - Complete operation logging for debugging

### 💾 Flexible Filesystem Options
- **ext4** - Traditional, stable filesystem with LVM
- **btrfs** - Advanced filesystem with snapshots and compression
  - Automatic subvolume creation (@, @var, @tmp, @swap, @home)
  - Integration with Snapper for automated snapshots
- **rEFInd bootloader** - Modern UEFI boot manager with multiple kernel options
- **refind-btrfs-snapshots** - Adds BTRFS snapshots to rEFInd boot menu (when using btrfs)

### ⚙️ Automated Configuration
- **System services** - Automated service configuration
- **User environment** - Complete user setup with directories and permissions
- **Dotfiles integration** - Automatic dotfiles deployment (see configuration section)
- **BTRFS snapshots** - Automated system snapshots with Snapper (when using btrfs)
- **Cron jobs** - System maintenance automation

## Installation Process

The installation follows these phases:

### Phase 1: System Preparation
- ✅ Prerequisites validation (UEFI, internet)
- ✅ System clock synchronization
- ✅ Automatic timezone detection

### Phase 2: Storage Configuration
- 🔧 Filesystem selection (ext4 or btrfs)
- 🔧 Partition creation (2GB EFI + remaining for LUKS)
- 🔐 LUKS encryption setup with password
- 💾 LVM configuration (for ext4) or direct formatting (optional for btrfs)
- 📁 Filesystem formatting with subvolumes (btrfs) or logical volumes (ext4)

### Phase 3: Base System
- 📦 Base system installation with pacstrap
- ⚙️ System configuration (locale, timezone, hostname)
- 🥾 rEFInd bootloader installation and configuration
- 👤 User account creation with sudo access

### Phase 4: Package Installation
- 📚 Official repository packages
- 🔧 AUR packages (development and specialized tools)
- 🎯 Development tools (Rust, Go, Python, etc.)

### Phase 5: Post-Installation
- 🔧 System service configuration
- 🔐 Secondary LUKS storage setup (if configured)
- 📸 Initial BTRFS snapshots (if using btrfs)
- 🏠 User directory structure creation
- 📋 Cron job configuration

## Dotfiles Integration

**Important**: If you have a dotfiles repository, place it in the [`config/dotfiles/`](config/dotfiles/) directory before running the installation. The system looks for an initialization script at:

```
config/dotfiles/extra/init-scripts/init-user.sh
```

This script will be automatically executed during post-installation with the following parameters:
- `$1` - Mount point (`/mnt`)
- `$2` - Username

Example dotfiles structure:
```
config/dotfiles/
├── extra/
│   └── init-scripts/
│       └── init-user.sh      # Your dotfiles setup script
├── .bashrc
└── ... (your dotfiles)
```

The [`init-user.sh`](config/dotfiles/extra/init-scripts/init-user.sh) script should handle:
- Dotfiles symlinking or copying
- Shell configuration
- Application-specific setup
- User-specific service initialization

## Filesystem Options

### ext4 with LVM (Recommended for Stability)
- Uses LVM for flexible volume management
- Separate `/` and `/home` logical volumes
- Traditional, well-tested filesystem
- Easy recovery and resizing

### btrfs (Advanced Features)
- Can be used with or without LVM
- Automatic subvolume creation:
  - `@` - Root filesystem
  - `@var` - Variable data
  - `@tmp` - Temporary files
  - `@swap` - Swap area
  - `@home` - User home directories
- Built-in snapshot support with Snapper integration

## Customization

### Adding Packages
Edit [`packages/programs.csv`](packages/programs.csv) to add packages:
```csv
official,package-name
aur,aur-package-name
```

### Custom Configuration
- Add scripts to [`config/system/`](config/system/) for system-level configuration
- Add scripts to [`config/apps/`](config/apps/) for application configuration
- Modify [`config/post-install.sh`](config/post-install.sh) to include new configuration steps

### Service Management
Services are automatically configured in:
- [`config/system/systemd-services.sh`](config/system/systemd-services.sh) - Enable/disable services
- Individual app configuration files handle service-specific setup

## Error Handling and Recovery

The system includes comprehensive error handling:
- **Task-level error tracking** with detailed reporting
- **Automatic cleanup** on failure
- **Safe unmounting** of filesystems
- **LUKS device closure** on errors
- **Detailed logging** for troubleshooting

## Logging and Debugging

All operations are logged to `/var/log/arch-install-$(date +%Y%m%d-%H%M%S).log` with:
- **Task-specific sections** for easy debugging
- **Error context** with full command output
- **Progress tracking** with visual feedback

## License and Support

This project is designed for personal use and educational purposes. While the scripts are provided as-is, the modular design makes debugging and customization straightforward.

For issues:
1. Check the installation log at `/var/log/arch-install-$(date +%Y%m%d-%H%M%S).log`
2. Review the specific module that failed
3. Verify system requirements are met
4. Test individual components in isolation

---

**Warning**: This installer will completely wipe the target disk and create a new encrypted installation. Ensure you have backups of any important data before running.