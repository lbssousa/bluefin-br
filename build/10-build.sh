#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Remove packages whose files are overridden by @projectbluefin/common.
# Without removal, these RPM-owned files would be lost if those packages were ever removed,
# and dnf would consider the RPM DB state inconsistent.
dnf remove -y ublue-os-luks ublue-os-just ublue-os-udev-rules ublue-os-signing ublue-os-update-services

# Copy shared system files from @projectbluefin/common (common baseline for all ublue images)
rsync -rvK /ctx/oci/common/shared/ /
# Copy Bluefin-specific system files from @projectbluefin/common (overrides the shared baseline)
rsync -rvK /ctx/oci/common/bluefin/ /
# Copy GNOME extensions from local system_files (includes git submodules)
rsync -rvK /ctx/system_files/shared/ /
# Copy Homebrew integration system files from @ublue-os/brew
rsync -rvK /ctx/oci/brew/ /

echo "::endgroup::"

echo "::group:: Configure Image Signing Policy"

# Install cosign public key so the system can verify images from ghcr.io/lbssousa
install -Dm0644 /ctx/cosign.pub /usr/lib/pki/containers/lbssousa.pub

# Add ghcr.io/lbssousa to the container signing policy so that rpm-ostree
# reports images as "ostree-image-signed:" instead of "ostree-unverified-registry:"
jq '.transports.docker["ghcr.io/lbssousa"] = [
  {
    "type": "sigstoreSigned",
    "keyPath": "/usr/lib/pki/containers/lbssousa.pub",
    "signedIdentity": { "type": "matchRepository" }
  }
]' /etc/containers/policy.json > /tmp/policy.json.tmp
mv /tmp/policy.json.tmp /etc/containers/policy.json

# Enable sigstore attachment lookups for ghcr.io/lbssousa
cat > /etc/containers/registries.d/ghcr.io-lbssousa.yaml << 'EOF'
docker:
  ghcr.io/lbssousa:
    use-sigstore-attachments: true
EOF

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Remove Packages"

# Remove packages not present in upstream Bluefin
EXCLUDED_PACKAGES=(
    gnome-software
    gnome-software-rpm-ostree
)

readarray -t INSTALLED_EXCLUDED < <(rpm -qa --queryformat='%{NAME}\n' "${EXCLUDED_PACKAGES[@]}" 2>/dev/null || true)
if [[ "${#INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
    dnf5 remove -y "${INSTALLED_EXCLUDED[@]}"
else
    echo "No excluded packages found to remove."
fi

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
dnf5 install -y \
    glow \
    jetbrains-mono-fonts-all \
    just

# Install nerd-fonts from COPR (provides JetBrainsMono Nerd Font family)
copr_install_isolated "che/nerd-fonts" "nerd-fonts"

echo "::endgroup::"

# Build GNOME Extensions (handles its own ::group:: grouping)
bash /ctx/build/build-gnome-extensions.sh

echo "::group:: Generate Image Info"

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
image_name="${IMAGE_NAME:-bluefin-br}"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/lbssousa/${image_name}"

image_flavor="${IMAGE_FLAVOR:-main}"

mkdir -p /usr/share/ublue-os
cat > "${IMAGE_INFO}" << EOF
{
  "image-name": "${image_name}",
  "image-flavor": "${image_flavor}",
  "image-vendor": "lbssousa",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${IMAGE_TAG:-stable-daily}",
  "base-image-name": "silverblue"
}
EOF

echo "::endgroup::"

echo "::group:: Regenerate Initramfs (for Plymouth theme)"

KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"${KERNEL_SUFFIX}"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"${KERNEL_SUFFIX}"'-)//')"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${QUALIFIED_KERNEL}" --reproducible -v --add ostree -f "/lib/modules/${QUALIFIED_KERNEL}/initramfs.img"
chmod 0600 "/lib/modules/${QUALIFIED_KERNEL}/initramfs.img"

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Install DX packages when building the dx image variant
if [[ "${IMAGE_FLAVOR:-main}" == "dx" ]]; then
    bash /ctx/build/dx.sh
fi

# Install proprietary NVIDIA drivers when building the nvidia image variant
if [[ "${IS_NVIDIA_LTS:-false}" == "true" ]]; then
    bash /ctx/build/nvidia-lts.sh
fi

# Install open NVIDIA drivers when building the nvidia-open image variant
if [[ "${IS_NVIDIA_OPEN:-false}" == "true" ]]; then
    bash /ctx/build/nvidia-open.sh
fi

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
