# vim: set ft=make :
#######################
### custom-system.just
#######################

# Change the default shell for the current user
[group('System')]
change-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    CURRENT_SHELL="$(getent passwd "$(id -un)" | cut -d: -f7)"
    AVAILABLE_SHELLS="$(grep -v '^#\|^$' /etc/shells)"
    echo "Current shell: ${CURRENT_SHELL}"
    SELECTED_SHELL="$(echo "${AVAILABLE_SHELLS}" | gum choose --header "Select your default shell:")" || { echo "No shell selected. No changes made."; exit 0; }
    if [[ -z "${SELECTED_SHELL}" ]]; then
        echo "No shell selected. No changes made."
        exit 0
    fi
    if [[ "${SELECTED_SHELL}" == "${CURRENT_SHELL}" ]]; then
        echo "Shell is already set to ${SELECTED_SHELL}. No changes made."
        exit 0
    fi
    if ! pkexec usermod -s "${SELECTED_SHELL}" "$(id -un)"; then
        echo "Failed to change shell. Authentication may have been cancelled or an error occurred."
        exit 1
    fi
    echo "Default shell changed to ${SELECTED_SHELL}. Log out and back in for the change to take effect."

# Toggle between bluefin-br and the Developer Experience (overrides Bluefin default for bluefin-br naming)
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    set -e
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_NAME="$(jq -rc '."image-name"' "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -rc '."image-ref"' "${IMAGE_INFO_FILE}" | sed "s/.*ghcr/ghcr/")"
    CURRENT_IMAGE="${IMAGE_REF}:$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"
    set +e

    if [[ "${IMAGE_NAME}" =~ -dx(-|$) ]] ; then
        gum confirm "Would you like to disable developer mode?" || exit 0
        echo "Rebasing to a non developer image"
        NEW_IMAGE="$(sed "s/-dx//" <<< "${CURRENT_IMAGE}")"
        pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
        exit 0
    fi

    gum confirm "Would you like to enable developer mode?" || exit 0
    echo "Rebasing to a developer image"
    NEW_IMAGE="$(sed "s|/bluefin-br|/bluefin-br-dx|" <<< "${CURRENT_IMAGE}")"
    pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
    if gum confirm "Do you want to also install the default development flatpaks?" ; then
        ADD_DEVMODE=1 ujust install-system-flatpaks 0 1
    fi
    if gum confirm "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi
    echo "Use ujust dx-group to add your user to the correct groups and complete the installation after rebooting into the development image"

# Switch between base, nvidia (proprietary), and nvidia-open image variants
[group('System')]
toggle-nvidia:
    #!/usr/bin/env bash
    set -e
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_NAME="$(jq -rc '."image-name"' "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -rc '."image-ref"' "${IMAGE_INFO_FILE}" | sed "s/.*ghcr/ghcr/")"
    CURRENT_IMAGE="${IMAGE_REF}:$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"

    if [[ "${IMAGE_NAME}" =~ -nvidia-open ]]; then
        CURRENT_VARIANT="nvidia-open"
    elif [[ "${IMAGE_NAME}" =~ -nvidia ]]; then
        CURRENT_VARIANT="nvidia"
    else
        CURRENT_VARIANT="base"
    fi

    echo "Current variant: ${CURRENT_VARIANT}"
    TARGET=$(gum choose --header "Select target NVIDIA variant:" "base" "nvidia" "nvidia-open")

    if [[ "${TARGET}" == "${CURRENT_VARIANT}" ]]; then
        echo "Already on the ${TARGET} variant. No changes made."
        exit 0
    fi

    # Strip any existing nvidia suffix to get the base image path
    BASE_IMAGE="$(sed -E 's/-nvidia(-open)?//' <<< "${CURRENT_IMAGE}")"

    case "${TARGET}" in
        "base")
            NEW_IMAGE="${BASE_IMAGE}"
            ;;
        "nvidia")
            NEW_IMAGE="$(sed "s/:/-nvidia:/" <<< "${BASE_IMAGE}")"
            ;;
        "nvidia-open")
            NEW_IMAGE="$(sed "s/:/-nvidia-open:/" <<< "${BASE_IMAGE}")"
            ;;
    esac

    gum confirm "Switch to ${NEW_IMAGE}?" || exit 0
    pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
    if [[ "${TARGET}" != "base" ]]; then
        echo ""
        echo "Switched to the ${TARGET} image variant."
        echo "After rebooting, run 'ujust enroll-secure-boot-key' and reboot again"
        echo "to complete the one-time Secure Boot MOK enrollment."
        echo "When prompted at the MOK Manager screen, enter the password: universalblue"
    fi

# Run a system benchmark (requires stress-ng from Homebrew)
[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        echo "stress-ng is not installed."
        if command -v brew &>/dev/null; then
            if gum confirm "Install stress-ng via Homebrew?" ; then
                brew install stress-ng
                brew link stress-ng
            else
                exit 0
            fi
        else
            echo "Please install stress-ng to run benchmarks."
            exit 1
        fi
    fi
    echo 'Running a 1 minute benchmark...'
    pushd $(mktemp -d) > /dev/null
    stress-ng --matrix 0 -t 1m --times
    popd > /dev/null

# Configure docker and libvirt groups for development
[group('System')]
configure-dev-groups:
    #!/usr/bin/pkexec bash
    CURRENT_USER="{{ `id -un` }}"
    echo "Adding $CURRENT_USER to docker and libvirt groups..."

    # Ensure groups exist in /etc/group
    for group in docker libvirt; do
        if ! grep -q "^$group:" /etc/group; then
            echo "Adding $group to /etc/group"
            grep "^$group:" /usr/lib/group | tee -a /etc/group > /dev/null
        fi
        usermod -aG $group $CURRENT_USER
    done

    echo "Groups configured. Log out and back in for changes to take effect."

# Example toggle command with user choice
[group('System')]
toggle-example-feature:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "This is an example toggle command."
    echo "Current status: [check your status here]"
    OPTION=$(Choose "Enable" "Disable" "Cancel")
    case "$OPTION" in
        "Enable")
            echo "Enabling feature..."
            # Add your enable logic here
            ;;
        "Disable")
            echo "Disabling feature..."
            # Add your disable logic here
            ;;
        "Cancel")
            echo "No changes made."
            ;;
    esac

# Clean up container images and volumes
[group('Maintenance')]
clean-containers:
    #!/usr/bin/bash
    echo "Cleaning up Podman containers, images, and volumes..."
    podman system prune -af
    podman volume prune -f
    echo "Cleanup complete!"

# Update system and reboot if needed
[group('Maintenance')]
update-and-reboot:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "Updating system..."
    sudo bootc upgrade
    if gum confirm "Reboot now to apply updates?"; then
        systemctl reboot
    else
        echo "Reboot later to apply updates."
    fi
