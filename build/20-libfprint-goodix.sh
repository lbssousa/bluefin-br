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

# Fix GCC 14 incompatible-pointer-types errors (treated as hard errors since GCC 14).
# In goodix52xd.c and goodix53xd.c, `payload` is `guint8[]` so `&payload` yields
# `guint8(*)[N]` instead of the expected `guint8*`.  Dropping the `&` lets the array
# decay to `guint8*` as required.
# In goodix511.c, `payload` is a `GoodixDefault` struct so we need an explicit cast.
sed -i \
    -e 's/goodix_tls_read_image(dev, \&payload, sizeof(payload), on_scan_empty_img, ssm)/goodix_tls_read_image(dev, payload, sizeof(payload), on_scan_empty_img, ssm)/' \
    -e 's/goodix_tls_read_image(dev, \&payload, sizeof(payload), scan_on_read_img, ssm)/goodix_tls_read_image(dev, payload, sizeof(payload), scan_on_read_img, ssm)/' \
    libfprint/drivers/goodixtls/goodix52xd.c \
    libfprint/drivers/goodixtls/goodix53xd.c

sed -i \
    -e 's/goodix_tls_read_image(dev, \&payload, sizeof(payload), on_scan_empty_img, ssm)/goodix_tls_read_image(dev, (guint8*)\&payload, sizeof(payload), on_scan_empty_img, ssm)/' \
    -e 's/goodix_tls_read_image(dev, \&payload, sizeof(payload), scan_on_read_img, ssm)/goodix_tls_read_image(dev, (guint8*)\&payload, sizeof(payload), scan_on_read_img, ssm)/' \
    libfprint/drivers/goodixtls/goodix511.c

# In goodix.c, `data` is `guint8*` but is assigned to a `GoodixPresetPskResponse*`
# without a cast.  Add an explicit cast to suppress the GCC 14 hard error.
sed -i \
    -e 's/GoodixPresetPskResponse\* response = data + sizeof(guint8);/GoodixPresetPskResponse* response = (GoodixPresetPskResponse*)(data + sizeof(guint8));/' \
    libfprint/drivers/goodixtls/goodix.c

echo "::endgroup::"

echo "::group:: Build libfprint with Goodix TLS drivers"

# Disable ccache for this build: the /var/cache mount is shared across all
# parallel image-variant builds, and concurrent ccache processes conflict
# with "File exists" errors when writing to the same hash files.
export CCACHE_DISABLE=1

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

unset CCACHE_DISABLE

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
