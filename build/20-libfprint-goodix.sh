#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Build and Install libfprint with Goodix 538d Fingerprint Reader Support
###############################################################################
# Builds a modified libfprint from the Infinytum fork which adds community-
# developed Goodix TLS drivers that are not present in upstream libfprint:
#
#   - goodixtls511  – Goodix 5110 sensor
#   - goodixtls52xd – Goodix 52xd family
#   - goodixtls53xd – Goodix 53xd family (includes 538d, USB 27c6:538d)
#
# The fork is based on libfprint 1.94.1 (LGPL-2.1+) and preserves the same
# ABI/soversion (libfprint-2.so.2) so fprintd and other consumers stay
# compatible.
#
# Source:  https://github.com/infinytum/libfprint (branch: unstable)
# AUR ref: https://aur.archlinux.org/packages/libfprint-goodix-521d
###############################################################################

# Pinned commit for reproducibility (tip of the "unstable" branch)
LIBFPRINT_GOODIX_COMMIT="5e14af7f136265383ca27756455f00954eef5db1"
LIBFPRINT_GOODIX_URL="https://github.com/infinytum/libfprint"

echo "::group:: Install Build Dependencies for libfprint (Goodix)"

dnf5 install -y \
    gcc \
    gcc-c++ \
    git \
    glib2-devel \
    gobject-introspection-devel \
    gtk-doc \
    libgudev-devel \
    libgusb-devel \
    meson \
    nss-devel \
    openssl-devel \
    pixman-devel \
    systemd-devel

echo "::endgroup::"

echo "::group:: Clone libfprint (Infinytum fork, Goodix TLS drivers)"

LIBFPRINT_BUILD_DIR=$(mktemp -d)
trap 'rm -rf "${LIBFPRINT_BUILD_DIR}"' EXIT

git clone --branch unstable "${LIBFPRINT_GOODIX_URL}" "${LIBFPRINT_BUILD_DIR}/libfprint"
cd "${LIBFPRINT_BUILD_DIR}/libfprint"
git checkout "${LIBFPRINT_GOODIX_COMMIT}"

echo "::endgroup::"

echo "::group:: Build libfprint with Goodix TLS drivers"

meson setup builddir \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    -Ddrivers=default \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=true \
    -Dudev_rules=enabled \
    -Dudev_hwdb=disabled

meson compile -C builddir

echo "::endgroup::"

echo "::group:: Install libfprint (replaces system version)"

meson install -C builddir

# Update the linker cache so the new library is found
ldconfig

echo "::endgroup::"

echo "::group:: Cleanup Build Dependencies"

# Leave git, meson, and gcc if other scripts still need them (the
# build-gnome-extensions.sh script already removes gcc/meson later).
# Remove only the development libraries that are exclusively ours.
dnf5 remove -y \
    gtk-doc \
    nss-devel \
    openssl-devel \
    pixman-devel

# Remove temporary build directory (also cleaned by trap)
trap - EXIT
rm -rf "${LIBFPRINT_BUILD_DIR}"

echo "::endgroup::"

echo "libfprint (Goodix 538d) build complete!"
