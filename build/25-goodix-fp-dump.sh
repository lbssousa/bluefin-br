#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install goodix-fp-dump scripts and Python virtual environment
###############################################################################
# Installs the goodix-fp-dump toolkit from the goodix-fp-linux-dev project,
# which provides Python scripts for communicating with and dumping firmware
# from Goodix fingerprint sensors over USB (and SPI for embedded boards).
#
# Source:   https://github.com/goodix-fp-linux-dev/goodix-fp-dump
# Firmware: https://github.com/goodix-fp-linux-dev/goodix-firmware (submodule)
#
# Scripts are installed to /opt/goodix-fp-dump with a Python virtual
# environment pre-populated with all required dependencies.
###############################################################################

# Pinned commit for reproducibility (tip of the default branch as of 2026-04-17)
GOODIX_FP_DUMP_COMMIT="cc43bb3b3154a0bccc0412ae024013c7e1923139"
GOODIX_FP_DUMP_URL="https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git"
GOODIX_FP_DUMP_DIR="/opt/goodix-fp-dump"

echo "::group:: Install Build Dependencies for goodix-fp-dump"

dnf5 install -y \
    gcc \
    git \
    kernel-headers \
    python3 \
    python3-devel \
    python3-pip

echo "::endgroup::"

echo "::group:: Clone goodix-fp-dump (pinned commit ${GOODIX_FP_DUMP_COMMIT})"

git clone "${GOODIX_FP_DUMP_URL}" "${GOODIX_FP_DUMP_DIR}"
cd "${GOODIX_FP_DUMP_DIR}"
git checkout "${GOODIX_FP_DUMP_COMMIT}"
git submodule update --init --recursive

# Remove git history to reduce image size
rm -rf "${GOODIX_FP_DUMP_DIR}/.git"
rm -rf "${GOODIX_FP_DUMP_DIR}/firmware/.git"

echo "::endgroup::"

echo "::group:: Create Python virtual environment and install dependencies"

python3 -m venv "${GOODIX_FP_DUMP_DIR}/.venv"
"${GOODIX_FP_DUMP_DIR}/.venv/bin/pip" install --no-cache-dir -r "${GOODIX_FP_DUMP_DIR}/requirements.txt"

echo "::endgroup::"

echo "::group:: Cleanup Build Dependencies"

dnf5 remove -y \
    kernel-headers \
    python3-devel

echo "::endgroup::"

echo "goodix-fp-dump installation complete! Scripts are at ${GOODIX_FP_DUMP_DIR}"
