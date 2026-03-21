#!/usr/bin/bash

###############################################################################
# NVIDIA LTS (Proprietary) Driver Install Script
###############################################################################
# Installs proprietary NVIDIA drivers for the bluefin-br-nvidia image variants.
# This script is called from 10-build.sh when IS_NVIDIA_LTS=true.
#
# Pre-built kernel modules and driver RPMs are provided by the UBlue
# akmods-nvidia-lts image, mounted at /tmp/akmods-nv-rpms by Containerfile.nvidia.
# These use traditional (non-open) NVIDIA kernel modules from the negativo17
# fedora-nvidia-lts repository — the latest available in the proprietary track.
#
# Based on the ublue-os/main nvidia-install.sh pattern:
# https://github.com/ublue-os/main/blob/main/build_files/nvidia-install.sh
###############################################################################

set -eoux pipefail

echo "::group:: Install NVIDIA LTS (Proprietary) Drivers"

# The akmods-nvidia-lts RPMs are mounted at this path by Containerfile.nvidia
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
    "${AKMODS_PATH}/ublue-os/nvidia-install.sh"

# Add kernel boot arguments to blacklist the nouveau driver and enable
# NVIDIA DRM kernel mode-setting (required for Wayland)
mkdir -p /usr/lib/bootc/kargs.d
tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

echo "::endgroup::"

echo "NVIDIA LTS build complete!"
