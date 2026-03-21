#!/usr/bin/bash

###############################################################################
# NVIDIA Driver Install Script
###############################################################################
# Installs NVIDIA proprietary drivers from pre-built akmods RPMs.
#
# Based on ublue-os/main build_files/nvidia-install.sh:
# https://github.com/ublue-os/main/blob/main/build_files/nvidia-install.sh
#
# Environment variables:
#   AKMODNV_PATH  - path to the mounted akmods RPMs (default: /tmp/akmods-rpms)
#   IMAGE_NAME    - image name for variant package selection
#   MULTILIB      - set to "1" to install 32-bit packages (default: 1)
###############################################################################

set -eoux pipefail

: "${AKMODNV_PATH:=/tmp/akmods-rpms}"
: "${MULTILIB:=1}"

FRELEASE="$(rpm -E %fedora)"

# Source nvidia-vars for KERNEL_VERSION, NVIDIA_AKMOD_VERSION, DIST_ARCH, KMOD_REPO
# shellcheck source=/dev/null
source "${AKMODNV_PATH}"/kmods/nvidia-vars

# diagnostic: list akmods directory
find "${AKMODNV_PATH}"/

# Verify that the akmods kernel matches the base image kernel to catch
# version mismatches (e.g. Fedora 42 akmods + Fedora 43 base) early.
BASE_KERNEL="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
if [[ "${BASE_KERNEL}" != "${KERNEL_VERSION}" ]]; then
    echo "ERROR: Kernel version mismatch between akmods image and base image!"
    echo "  Base image kernel : ${BASE_KERNEL}"
    echo "  Akmods kernel     : ${KERNEL_VERSION}"
    echo "  Update image-versions.yml so that akmods-nvidia-lts-main uses the"
    echo "  tag matching the current Fedora release of silverblue-main (e.g. main-43)."
    exit 1
fi

if ! command -v dnf5 >/dev/null; then
    echo "Requires dnf5... Exiting"
    exit 1
fi

# Check if any rpmfusion repos exist before trying to disable them
if dnf5 repolist --all | grep -q rpmfusion; then
    dnf5 config-manager setopt "rpmfusion*".enabled=0
fi

# Disable cisco repo
dnf5 config-manager setopt fedora-cisco-openh264.enabled=0

## nvidia install steps
dnf5 install -y "${AKMODNV_PATH}"/ublue-os/ublue-os-nvidia-addons-*.rpm

# Install MULTILIB packages from negativo17-multimedia prior to disabling repo
if [[ "$(rpm -E '%{_arch}')" == "x86_64" && "${MULTILIB}" == "1" ]]; then
    MULTILIB_PKGS=(
        mesa-dri-drivers.i686
        mesa-filesystem.i686
        mesa-libEGL.i686
        mesa-libGL.i686
        mesa-libgbm.i686
        mesa-vulkan-drivers.i686
    )
    dnf5 install -y "${MULTILIB_PKGS[@]}"
fi

# Enable repos provided by ublue-os-nvidia-addons
# Use wildcard to enable both fedora-nvidia and fedora-nvidia-lts as appropriate
dnf5 config-manager setopt "fedora-nvidia*".enabled=1 nvidia-container-toolkit.enabled=1

# Disable Multimedia repo to ensure negativo17-fedora-nvidia is used
NEGATIVO17_MULT_PREV_ENABLED=N
if dnf5 repolist --enabled | grep -q "fedora-multimedia"; then
    NEGATIVO17_MULT_PREV_ENABLED=Y
    echo "disabling negativo17-fedora-multimedia to ensure negativo17-fedora-nvidia is used"
    dnf5 config-manager setopt fedora-multimedia.enabled=0
fi

# Enable staging COPR for supergfxctl
# Use curl to download repo file directly (more robust than dnf5 copr enable)
STAGING_ENABLED=false
if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
    STAGING_ENABLED=true
elif [[ -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo" ]]; then
    sed -i 's@enabled=0@enabled=1@g' "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo"
    STAGING_ENABLED=true
elif curl --fail -Lo /etc/yum.repos.d/_copr_ublue-os-staging.repo \
        "https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-${FRELEASE}/ublue-os-staging-fedora-${FRELEASE}.repo"; then
    STAGING_ENABLED=true
else
    echo "WARNING: Could not download ublue-os/staging COPR repo (Fedora ${FRELEASE}); variant packages will be skipped"
fi

if [[ "${IMAGE_NAME}" == "kinoite" ]]; then
    VARIANT_PKGS=(
        supergfxctl
    )
elif [[ "${IMAGE_NAME}" == "silverblue" ]]; then
    VARIANT_PKGS=(
        gnome-shell-extension-supergfxctl-gex
        supergfxctl
    )
else
    VARIANT_PKGS=()
fi

# Only include variant packages if the staging COPR is available
if [[ "${STAGING_ENABLED}" != "true" ]]; then
    VARIANT_PKGS=()
fi

NVIDIA_RPMS=(
    "${AKMODNV_PATH}"/nvidia/*."$(rpm -E '%{_arch}')".rpm
    "${AKMODNV_PATH}"/nvidia/*.noarch.rpm
    nvidia-container-toolkit
    egl-wayland
    libva-nvidia-driver
    "${VARIANT_PKGS[@]+"${VARIANT_PKGS[@]}"}"
    "${AKMODNV_PATH}"/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}"."${DIST_ARCH}".rpm
)

if [[ "$(rpm -E '%{_arch}')" == "x86_64" && "${MULTILIB}" == "1" ]]; then
    NVIDIA_RPMS+=(
        "${AKMODNV_PATH}"/nvidia/*.i686.rpm
    )
fi

dnf5 install -y "${NVIDIA_RPMS[@]}"

# Ensure the version of the NVIDIA kmod matches the driver
KMOD_VERSION="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia)"
DRIVER_VERSION="$(rpm -q --queryformat '%{VERSION}' nvidia-driver)"
if [ "${KMOD_VERSION}" != "${DRIVER_VERSION}" ]; then
    echo "Error: kmod-nvidia version (${KMOD_VERSION}) does not match nvidia-driver version (${DRIVER_VERSION})"
    exit 1
fi

## nvidia post-install steps
# Disable repos provided by ublue-os-nvidia-addons
dnf5 config-manager setopt "fedora-nvidia*".enabled=0 nvidia-container-toolkit.enabled=0

# Disable staging COPR if it was enabled
if [[ "${STAGING_ENABLED}" == "true" ]]; then
    if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
        sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
    elif [[ -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo"
    fi
fi

systemctl enable ublue-nvctk-cdi.service
semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp

# Force NVIDIA driver load to fix black screen on boot for NVIDIA desktops
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
# Pre-load intel/amd iGPU so chromium web browsers can use hardware acceleration
sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# Re-enable negativo17-multimedia if it was disabled
if [[ "${NEGATIVO17_MULT_PREV_ENABLED}" = "Y" ]]; then
    dnf5 config-manager setopt fedora-multimedia.enabled=1
fi
