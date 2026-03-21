#!/usr/bin/bash

###############################################################################
# DX (Developer Experience) Build Script
###############################################################################
# Installs developer-focused packages for the bluefin-br-dx image variants.
# This script is called from 10-build.sh when IMAGE_FLAVOR=dx.
#
# Based on the original Bluefin dx package set:
# https://github.com/ublue-os/bluefin/blob/main/build_files/dx/00-dx.sh
###############################################################################

set -eoux pipefail

echo "::group:: Install DX Packages"

# DX packages from Fedora repos
FEDORA_PACKAGES=(
    # Containerization and virtualisation tools
    cockpit-bridge
    cockpit-machines
    cockpit-networkmanager
    cockpit-ostree
    cockpit-podman
    cockpit-selinux
    cockpit-storaged
    cockpit-system
    edk2-ovmf
    flatpak-builder
    libvirt
    libvirt-nss
    podman-compose
    podman-machine
    podman-tui
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    virt-manager
    virt-viewer
    # Developer tools and fonts
    bcc
    bpftrace
    cascadia-code-fonts
    git-subtree
    git-svn
    iotop
    nicstat
    numactl
    p7zip
    p7zip-plugins
    sysprof
    trace-cmd
    udica
    util-linux-script
)

echo "Installing ${#FEDORA_PACKAGES[@]} DX packages from Fedora repos..."
dnf5 install -y "${FEDORA_PACKAGES[@]}"

# Docker CE from official repo
dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/docker-ce.repo
dnf5 install -y --enablerepo=docker-ce-stable \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin

# Visual Studio Code from Microsoft repo
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/vscode.repo
dnf5 install -y --enablerepo=code code

# Enable DX-specific services
systemctl enable docker.socket
systemctl enable podman.socket

echo "::endgroup::"

echo "DX build complete!"
