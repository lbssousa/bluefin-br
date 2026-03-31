#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install Epson Printer Software from Epson's website
###############################################################################
# Installs two packages obtained directly from Epson's Linux download portal:
#
# 1. epson-inkjet-printer-escpr - Epson Inkjet Printer Driver (ESC/P-R) for Linux
#    Source: https://support.epson.net/linux/Printer/LSB_distribution_pages/en/escpr.php
#    Built from Epson's source RPM to ensure compatibility with modern Fedora.
#
# 2. epson-printer-utility - Epson Printer Utility for Linux
#    Source: https://support.epson.net/linux/Printer/LSB_distribution_pages/en/utility.php
#    Installed from Epson's binary RPM package.
#
# Version update: run `.github/workflows/check-epson-updates.yml`
###############################################################################

# ── Pinned versions ────────────────────────────────────────────────────────
# renovate: datasource=custom.epson-escpr
ESCPR_VERSION="1.8.8"
ESCPR_SRPM_URL="https://download-center.epson.com/f/module/e934c1f6-0fc1-43e5-8d3e-0de8f3a3d357/epson-inkjet-printer-escpr-${ESCPR_VERSION}-1.src.rpm"

# renovate: datasource=custom.epson-printer-utility
UTILITY_VERSION="1.2.2"
UTILITY_RPM_URL="https://download-center.epson.com/f/module/0fd7dd73-92c2-451e-88cf-cf385e0f6db7/epson-printer-utility-${UTILITY_VERSION}-1.x86_64.rpm"
# ──────────────────────────────────────────────────────────────────────────

echo "::group:: Install Build Dependencies for ESC/P-R Driver"

dnf5 install -y \
    autoconf \
    automake \
    cups-devel \
    gcc \
    libtool \
    rpm-build

echo "::endgroup::"

echo "::group:: Install Runtime Dependencies"

dnf5 install -y \
    cups \
    cups-filters \
    ghostscript

echo "::endgroup::"

echo "::group:: Build and Install epson-inkjet-printer-escpr ${ESCPR_VERSION}"

ESCPR_BUILD_DIR=$(mktemp -d)
trap 'rm -rf "${ESCPR_BUILD_DIR}"' EXIT

curl -L --fail --output "${ESCPR_BUILD_DIR}/epson-inkjet-printer-escpr.src.rpm" \
    "${ESCPR_SRPM_URL}"

pushd "${ESCPR_BUILD_DIR}"
  rpm2cpio epson-inkjet-printer-escpr.src.rpm | cpio -idmv

  tar xzf "epson-inkjet-printer-escpr-${ESCPR_VERSION}-1.tar.gz"
  cd "epson-inkjet-printer-escpr-${ESCPR_VERSION}"

  autoreconf -vif
  # GCC 14 (Fedora 41+) promotes -Wimplicit-function-declaration to an error;
  # the Epson source predates this strictness. Suppress only that warning to
  # keep the rest of -Wall active.
  CFLAGS="${CFLAGS:--O2} -Wno-implicit-function-declaration" \
  ./configure \
      --prefix=/usr \
      --with-cupsfilterdir=/usr/lib/cups/filter \
      --with-cupsppddir=/usr/share/ppd
  make
  make install
popd

echo "::endgroup::"

echo "::group:: Install epson-printer-utility ${UTILITY_VERSION}"

UTILITY_RPM="${ESCPR_BUILD_DIR}/epson-printer-utility.x86_64.rpm"

curl -L --fail --output "${UTILITY_RPM}" \
    "${UTILITY_RPM_URL}"

# Install the binary RPM:
# --nodeps   : skip dependency checks (LSB compatibility shim not present on modern Fedora)
# --nodigest : skip payload-digest verification; RPM 4.19+ (Fedora 40+) rejects
#              packages built without a SHA-256 payload digest header, which
#              applies to this older Epson binary RPM
rpm -i --nodeps --nodigest "${UTILITY_RPM}"

echo "::endgroup::"

echo "::group:: Enable Services"

# Enable the Epson Connect Billing Daemon used by epson-printer-utility
systemctl enable ecbd.service || true

echo "::endgroup::"

echo "::group:: Cleanup Build Dependencies"

dnf5 remove -y \
    autoconf \
    automake \
    libtool \
    rpm-build

# Remove the Epson source/binary archives (build dir is cleaned by trap)
trap - EXIT
rm -rf "${ESCPR_BUILD_DIR}"

echo "::endgroup::"

echo "Epson printer software installation complete!"
