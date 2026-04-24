# vim: set ft=make :
############
# nix.just
############

# Show Nix installation status
[group('Nix')]
nix-status:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Nix Installation Status ==="
    if [[ -f /var/lib/nix/.nix-installed ]]; then
        echo "Status: Installed ✓"
        if command -v nix &>/dev/null; then
            echo "Version: $(nix --version 2>/dev/null || echo 'unknown')"
        fi
        if systemctl is-active --quiet nix-daemon.service 2>/dev/null; then
            echo "Daemon: active ✓"
        else
            echo "Daemon: inactive"
        fi
    elif systemctl is-active --quiet nix-first-boot.service 2>/dev/null; then
        echo "Status: Installing... (follow logs with: journalctl -u nix-first-boot.service -f)"
    elif systemctl is-failed --quiet nix-first-boot.service 2>/dev/null; then
        echo "Status: Installation failed"
        echo "Run 'ujust nix-install' to retry, or check the logs:"
        echo "  journalctl -u nix-first-boot.service"
    else
        echo "Status: Not installed"
        echo "Run 'ujust nix-install' to install Nix"
    fi

# Install Nix via DeterminateSystems nix-installer (triggers the first-boot service)
[group('Nix')]
nix-install:
    #!/usr/bin/bash
    set -euo pipefail
    if [[ -f /var/lib/nix/.nix-installed ]]; then
        echo "Nix is already installed."
        if command -v nix &>/dev/null; then
            echo "Version: $(nix --version)"
        fi
        exit 0
    fi
    echo "Starting Nix installation..."
    echo "This requires internet access to download Nix packages."
    echo ""
    # Reset any previously failed state so the service can be started again
    sudo systemctl reset-failed nix-first-boot.service 2>/dev/null || true
    # Ensure /var/lib/nix exists and nix.mount is active before running the installer
    sudo systemctl start nix.mount
    # Start the installer without blocking so we can follow logs immediately.
    # journalctl --no-tail shows all historical entries plus new ones, avoiding
    # any race condition between service start and log following.
    sudo systemctl start --no-block nix-first-boot.service
    echo "Following installation logs (Ctrl+C stops log output, not the install)..."
    sudo journalctl -u nix-first-boot.service --follow --no-tail || true
    # Verify the result after log following ends (user pressed Ctrl+C or service finished)
    if [[ -f /var/lib/nix/.nix-installed ]]; then
        echo ""
        echo "Nix installed successfully!"
        echo "Log out and back in to use Nix, or run:"
        echo "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    else
        echo ""
        echo "Installation is still in progress or may have failed."
        echo "Check status: journalctl -u nix-first-boot.service"
    fi

# Uninstall Nix using the DeterminateSystems uninstaller
[group('Nix')]
nix-uninstall:
    #!/usr/bin/bash
    set -euo pipefail
    if [[ ! -f /var/lib/nix/.nix-installed ]]; then
        echo "Nix is not installed."
        exit 0
    fi
    # Confirm before uninstalling – support gum (interactive) with a plain read fallback
    if command -v gum &>/dev/null; then
        if ! gum confirm "Uninstall Nix? This will remove all packages installed via Nix."; then
            echo "Operation cancelled."
            exit 0
        fi
    else
        read -rp "Uninstall Nix? This will remove all packages installed via Nix. [y/N] " _confirm
        if [[ "${_confirm,,}" != "y" ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
    echo "Uninstalling Nix..."
    sudo /usr/libexec/nix-installer uninstall --no-confirm
    sudo rm -f /var/lib/nix/.nix-installed
    echo "Nix uninstalled."
    echo "Note: /var/lib/nix may still contain residual files."
    echo "To remove completely, run: sudo rm -rf /var/lib/nix"
