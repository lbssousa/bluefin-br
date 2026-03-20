#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Build and Install BigLinux Parental Controls
###############################################################################
# Builds big-parental-controls from source:
# https://github.com/biglinux/big-parental-controls
#
# Provides ECA Digital (Lei 15.211/2025) compliance tools for Brazilian users:
#   - Supervised account management with GTK4/libadwaita UI
#   - Age-range signaling (D-Bus) per ECA Digital ranges
#   - Web filtering via nftables DNS redirection
#   - Screen time limits via PAM rules
#   - Activity monitoring (local-first, no cloud)
###############################################################################

echo "::group:: Install Runtime Dependencies"

dnf5 install -y \
    python3 \
    python3-gobject \
    python3-cairo \
    gtk4 \
    libadwaita \
    malcontent \
    accountsservice \
    polkit \
    gettext \
    acl \
    nftables

echo "::endgroup::"

echo "::group:: Install Build Dependencies"

dnf5 install -y \
    rust \
    cargo \
    git

echo "::endgroup::"

echo "::group:: Clone and Build big-parental-controls"

BPC_DIR=$(mktemp -d)
export CARGO_HOME="${BPC_DIR}/cargo-home"

git clone --depth=1 https://github.com/biglinux/big-parental-controls.git "${BPC_DIR}/src"

INTERNAL_DIR="${BPC_DIR}/src/big-parental-controls"

# Build Rust unified daemon (age signal + parental monitor)
cd "${BPC_DIR}/src/big-age-signal"
cargo build --release

echo "::endgroup::"

echo "::group:: Install big-parental-controls"

# Copy all system files from big-parental-controls/usr to /usr
cp -r "${INTERNAL_DIR}/usr/"* /usr/

# Install the Rust daemon binary
install -Dm755 "${BPC_DIR}/src/big-age-signal/target/release/big-parental-daemon" \
    /usr/lib/big-parental-controls/big-parental-daemon

# Backward-compatibility symlink (big-age-signal → big-parental-daemon)
ln -sf /usr/lib/big-parental-controls/big-parental-daemon /usr/bin/big-age-signal

# Install Python package into system site-packages (not /usr/local which is a symlink on Fedora bootc)
PYTHON_VER=$(python3 -c 'import sys; print("{}.{}".format(sys.version_info.major, sys.version_info.minor))')
SITE_PACKAGES="/usr/lib/python${PYTHON_VER}/site-packages"
install -dm755 "${SITE_PACKAGES}/big_parental_controls"
cp -r "${BPC_DIR}/src/src/big_parental_controls/"* "${SITE_PACKAGES}/big_parental_controls/"

# Ensure executables are actually executable
chmod +x /usr/bin/big-parental-controls 2>/dev/null || true
chmod +x /usr/lib/big-parental-controls/group-helper 2>/dev/null || true
chmod +x /usr/lib/big-parental-controls/acl-reapply 2>/dev/null || true
chmod +x /usr/lib/big-parental-controls/time-check 2>/dev/null || true
chmod +x /usr/lib/big-parental-controls/pam-time-message 2>/dev/null || true

# Create persistent state directories (writable /var at runtime)
install -dm755 /var/lib/big-parental-controls
install -dm700 /var/lib/big-parental-controls/activity

echo "::endgroup::"

echo "::group:: Enable Services"

# Enable D-Bus daemon and boot/timer services
systemctl enable big-parental-daemon.service || true
systemctl enable big-parental-dns-restore.service || true
systemctl enable big-parental-time-check.timer || true

echo "::endgroup::"

echo "::group:: Cleanup Build Dependencies"

# Remove large build-only tools to keep the image lean
dnf5 remove -y rust cargo

# Remove the temporary build directory
rm -rf "${BPC_DIR}"

echo "::endgroup::"

echo "big-parental-controls build complete!"
