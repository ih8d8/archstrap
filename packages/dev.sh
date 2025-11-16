#!/usr/bin/env bash

# Source required utilities
DEV_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -z "${LOG_FILE:-}" ]]; then
    source "${DEV_SCRIPT_DIR}/../utils/logging.sh"
fi

# Install development tools
install_development_tools() {
    log "Installing development tools..."
    
    # Create a script to run inside chroot
    cat > /mnt/install_dev_tools.sh << EOF
#!/usr/bin/env bash
set -euo pipefail

# Configure passwordless sudo for the new user temporarily
echo '${NEW_USER} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp_install
chmod 440 /etc/sudoers.d/temp_install

# Install Rust
echo "Installing Rust..."
sudo -u ${NEW_USER} rustup default stable
sudo -u ${NEW_USER} cargo install cargo-cache

# Configure GOPATH
echo "Configuring GOPATH..."
sudo -u ${NEW_USER} go env -w GOPATH="/home/${NEW_USER}/.go"
mv /home/${NEW_USER}/go /home/${NEW_USER}/.go || true
chown -R ${NEW_USER}:wheel /home/${NEW_USER}/.go

# Install Node.js
echo "Installing Node.js and packages..."
sudo -u ${NEW_USER} bash -c "
    set -euo pipefail
    source /usr/share/nvm/init-nvm.sh
    nvm install --lts
"

# Remove temporary sudoers rule after installation
rm -f /etc/sudoers.d/temp_install

echo "Development tools installation completed successfully!"
EOF

    # Make script executable and run it in chroot
    chmod +x /mnt/install_dev_tools.sh
    arch-chroot /mnt ./install_dev_tools.sh || fatal_error "something went wrong while installing development tools!"
    
    # Clean up the script
    rm -f /mnt/install_dev_tools.sh
}