###############################################################################
# PROJECT NAME CONFIGURATION
###############################################################################
# Name: bluefin-br
#
# IMPORTANT: Change "bluefin-br" above to your desired project name.
# This name should be used consistently throughout the repository in:
#   - Justfile: export image_name := env("IMAGE_NAME", "your-name-here")
#   - README.md: # your-name-here (title)
#   - artifacthub-repo.yml: repositoryID: your-name-here
#   - custom/ujust/README.md: localhost/your-name-here:stable (in bootc switch example)
#
# The project name defined here is the single source of truth for your
# custom image's identity. When changing it, update all references above
# to maintain consistency.
###############################################################################

###############################################################################
# MULTI-STAGE BUILD ARCHITECTURE
###############################################################################
# This Containerfile follows the Bluefin architecture pattern as implemented in
# @projectbluefin/distroless. The architecture layers OCI containers together:
#
# 1. Context Stage (ctx) - Combines resources from:
#    - Local build scripts and custom files
#    - @projectbluefin/common - Desktop configuration shared with Aurora
#    - @ublue-os/brew - Homebrew integration
#
# 2. Base Image (silverblue-main):
#    - Fedora version and digest are controlled by FEDORA_MAJOR_VERSION and
#      BASE_IMAGE_DIGEST build args. These are set per stream:
#        - stable: pinned Fedora version (see image-versions.yml)
#        - latest: ghcr.io/ublue-os/silverblue-main:latest (see image-versions.yml)
#        - beta:   ghcr.io/ublue-os/silverblue-main:beta (see image-versions.yml)
#
# Image digests in image-versions.yml are automatically updated by Renovate.
#
# See: https://docs.projectbluefin.io/contributing/ for architecture diagram
###############################################################################

# ARG values are updated automatically by Renovate via image-versions.yml
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG COMMON_IMAGE_DIGEST="sha256:9409d0c08bf76bdfef52812db61a68453b20b23b52042e810a447ada3c72c9c1"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"
ARG BREW_IMAGE_DIGEST="sha256:fef8b4728cb042f6b69ad9be90a43095261703103fe6c0735c9d6f035065c052"
ARG FEDORA_MAJOR_VERSION="latest"
ARG BASE_IMAGE_DIGEST="sha256:c2ea2411fcab64e9dda37159e2922801bd57c632672737c6d3e9ae008b56d430"

FROM ${COMMON_IMAGE}@${COMMON_IMAGE_DIGEST} AS common
FROM ${BREW_IMAGE}@${BREW_IMAGE_DIGEST} AS brew

# Context stage - combine local and imported OCI container resources
FROM scratch AS ctx

COPY build /build
COPY custom /custom
# Copy from OCI containers to distinct subdirectories to avoid conflicts
COPY --from=common /system_files /oci/common
COPY --from=brew /system_files /oci/brew

# Base Image - GNOME included
FROM ghcr.io/ublue-os/silverblue-main:${FEDORA_MAJOR_VERSION}@${BASE_IMAGE_DIGEST}

## Alternative base images, no desktop included (uncomment to use):
# FROM ghcr.io/ublue-os/base-main:latest
# FROM quay.io/centos-bootc/centos-bootc:stream10

## Alternative GNOME OS base image (uncomment to use):
# FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly

### /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop, epson-printer-utility.
##
## The following line makes /opt an immutable real directory so that packages
## installed there (such as epson-printer-utility) are included in the image layers
## and correctly deployed by bootc.

RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Make modifications desired in your image and install packages by modifying the build scripts.
## The following RUN directive mounts the ctx stage which includes:
##   - Local build scripts from /build
##   - Local custom files from /custom
##   - Files from @projectbluefin/common at /oci/common
##   - Files from @projectbluefin/branding at /oci/branding
##   - Files from @ublue-os/artwork at /oci/artwork
##   - Files from @ublue-os/brew at /oci/brew
## Scripts are run in numerical order (10-build.sh, 20-example.sh, etc.)

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    find /ctx/build -maxdepth 1 -name '[0-9][0-9]-*.sh' -print0 | sort -z | xargs -0 -I{} bash {}
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
