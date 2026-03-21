#!/usr/bin/bash

###############################################################################
# NVIDIA Open Driver Install Script
###############################################################################
# Installs open-source NVIDIA drivers for the bluefin-br-nvidia-open image variants.
# This script is called from 10-build.sh when IS_NVIDIA_OPEN=true.
#
# Pre-built kernel modules and driver RPMs are provided by the UBlue
# akmods-nvidia-open image, mounted at /tmp/akmods-nv-rpms by Containerfile.nvidia-open.
# These use the open-source NVIDIA kernel modules from the negativo17
# fedora-nvidia repository — the latest open drivers available.
#
# The driver installation is handled by build/nvidia-install.sh (our own script
# based on the ublue-os/main pattern), which is more robust than calling the
# script bundled inside the akmods image.
###############################################################################

set -eoux pipefail

echo "::group:: Install NVIDIA Open Drivers"

# The akmods-nvidia-open RPMs are mounted at this path by Containerfile.nvidia-open
AKMODS_PATH=/tmp/akmods-nv-rpms

# IMAGE_NAME is used by nvidia-install.sh to select variant-specific packages
# (e.g., gnome-shell-extension-supergfxctl-gex for silverblue/GNOME)
IMAGE_NAME=silverblue

# MULTILIB=0: skip 32-bit (i686) multilib packages; they are not required
# for the BR customisation and keep the image smaller
MULTILIB=0

IMAGE_NAME="${IMAGE_NAME}" \
AKMODNV_PATH="${AKMODS_PATH}" \
MULTILIB="${MULTILIB}" \
    bash /ctx/build/nvidia-install.sh

# Regenerate the initramfs to include the NVIDIA kernel modules
# (required for proper NVIDIA driver loading at boot)
KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut \
    --no-hostonly \
    --kver "${KERNEL_VERSION}" \
    --reproducible \
    -v \
    --add ostree \
    -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

# Add kernel boot arguments to blacklist the nouveau driver and enable
# NVIDIA DRM kernel mode-setting (required for Wayland)
mkdir -p /usr/lib/bootc/kargs.d
tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

echo "::endgroup::"

echo "NVIDIA open build complete!"
