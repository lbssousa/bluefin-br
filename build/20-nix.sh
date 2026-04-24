#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install Nix (DeterminateSystems nix-installer) – Infrastructure Setup
###############################################################################
# Strategy for /nix on an immutable bootc/ostree system:
#
#   Problem: In a bootc deployment, / is read-only (ostree layer).
#            If /nix were baked into the image, the Nix store would be
#            immutable and Nix could not install or update packages.
#
#   Solution: Bind-mount approach
#     - /nix  → empty directory in the image (serves as the bind-mount point)
#     - /var/lib/nix → the REAL, persistent Nix store (lives in the mutable /var)
#     - nix.mount (systemd) bind-mounts /var/lib/nix → /nix on every boot
#
#   First-boot behavior:
#     - nix-first-boot.service detects /var/lib/nix/.nix-installed is absent
#     - Downloads Nix from cache.nixos.org (requires internet)
#     - Installs Nix into /nix (writes through bind-mount to /var/lib/nix)
#     - Creates nix-daemon.service / socket (enabled for subsequent boots)
#     - Touches /var/lib/nix/.nix-installed to prevent re-running
#
#   Subsequent boots:
#     - /var/lib/nix already populated → bind-mount makes it available at /nix
#     - nix-daemon.service starts normally
#     - nix-first-boot.service is skipped (ConditionPathExists check)
#
# Reference: https://github.com/DeterminateSystems/nix-installer
###############################################################################

echo "::group:: Download nix-installer binary"

# Detect build architecture and select the correct nix-installer binary
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)
        NIX_INSTALLER_ARCH="x86_64-linux"
        ;;
    aarch64)
        NIX_INSTALLER_ARCH="aarch64-linux"
        ;;
    *)
        echo "ERROR: Unsupported architecture for nix-installer: ${ARCH}"
        exit 1
        ;;
esac

# Download the DeterminateSystems nix-installer binary at build time.
# Storing it in the image avoids a network dependency for the installer itself
# on first boot (only Nix packages still require internet at first boot).
# renovate: datasource=github-releases depName=DeterminateSystems/nix-installer
NIX_INSTALLER_VERSION="latest"
curl -sSfL --retry 3 --retry-delay 10 \
    "https://github.com/DeterminateSystems/nix-installer/releases/${NIX_INSTALLER_VERSION}/download/nix-installer-${NIX_INSTALLER_ARCH}" \
    -o /usr/libexec/nix-installer
chmod 0755 /usr/libexec/nix-installer

echo "Downloaded nix-installer (${ARCH}) to /usr/libexec/nix-installer"

echo "::endgroup::"

echo "::group:: Create /nix bind-mount infrastructure"

# Create /nix as an empty directory to act as the bind-mount point.
# Since / is read-only after bootc deployment, the bind-mount from nix.mount
# will overlay this directory with the writable /var/lib/nix at runtime.
mkdir -p /nix

# tmpfiles.d: ensure /var/lib/nix (the persistent Nix store) exists with the right
# permissions before nix.mount tries to bind-mount it.
cat > /etc/tmpfiles.d/nix.conf << 'EOF'
# Persistent Nix store directory (mutable /var partition, survives bootc updates)
d /var/lib/nix 0755 root root -
EOF

# Systemd mount unit: bind-mount /var/lib/nix → /nix on every boot.
# The unit name must match the mount point: /nix → nix.mount.
cat > /etc/systemd/system/nix.mount << 'EOF'
[Unit]
Description=Nix Package Manager Store (/nix)
Documentation=https://nix.dev
# systemd-tmpfiles-setup creates /var/lib/nix; ensure it runs before we mount it
After=systemd-tmpfiles-setup.service
Requires=systemd-tmpfiles-setup.service

[Mount]
What=/var/lib/nix
Where=/nix
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
EOF

echo "::endgroup::"

echo "::group:: Create Nix first-boot installation service"

# Script executed by nix-first-boot.service.
# Runs nix-installer with systemd integration so the nix-daemon.service and
# nix-daemon.socket units are created and enabled for all future boots.
cat > /usr/libexec/nix-first-boot << 'EOF'
#!/usr/bin/bash

set -euo pipefail

echo "=== Nix first-boot installation ==="
echo "This process downloads Nix packages from cache.nixos.org."
echo "Please ensure you have an internet connection."

# Run the DeterminateSystems nix-installer.
# --init systemd          : create and enable nix-daemon.service / socket
# --no-confirm            : non-interactive (no prompts)
# --nix-build-user-count  : number of Nix build sandbox users (default: 32)
# --extra-conf            : disable seccomp syscall filtering; required in
#                           some virtualisation / container environments
/usr/libexec/nix-installer install linux \
    --init systemd \
    --no-confirm \
    --nix-build-user-count 32 \
    --extra-conf "filter-syscalls = false"

# Mark installation as complete so the service does not re-run on next boot
touch /var/lib/nix/.nix-installed

echo "=== Nix installation complete! ==="
echo "Log out and back in (or source the Nix profile) to use the nix command:"
echo "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
EOF

chmod 0755 /usr/libexec/nix-first-boot

# Systemd one-shot service: runs nix-first-boot on every boot until Nix is installed.
# The ConditionPathExists check prevents it from running again once complete.
cat > /etc/systemd/system/nix-first-boot.service << 'EOF'
[Unit]
Description=Install Nix Package Manager (DeterminateSystems) - first boot
Documentation=https://github.com/DeterminateSystems/nix-installer
# Require network connectivity – Nix packages are downloaded from cache.nixos.org
After=network-online.target nix.mount
Wants=network-online.target
# nix.mount must be active so the installer writes into /var/lib/nix via /nix
Requires=nix.mount
# Skip if Nix has already been installed (marker left by nix-first-boot script)
ConditionPathExists=!/var/lib/nix/.nix-installed

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/nix-first-boot
# Allow up to 10 minutes for package downloads on slow connections
TimeoutStartSec=600
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "::endgroup::"

echo "::group:: Enable Nix systemd units"

systemctl enable nix.mount
systemctl enable nix-first-boot.service

echo "::endgroup::"

echo "Nix infrastructure setup complete!"
