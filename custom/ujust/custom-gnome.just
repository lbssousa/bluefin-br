# vim: set ft=make :
######################
### custom-gnome.just
######################

# Toggle all Bluefin default GNOME customizations on/off
# Includes: minimize/maximize window buttons, monospace font, enabled extensions, and other interface settings
[group('System')]
toggle-bluefin-gnome:
    #!/usr/bin/env bash
    set -euo pipefail

    # Detect current state: check Bluefin-specific markers (minimize/maximize buttons and extensions)
    CURRENT_LAYOUT="$(gsettings get org.gnome.desktop.wm.preferences button-layout)"
    CURRENT_EXTENSIONS="$(gsettings get org.gnome.shell enabled-extensions)"
    if echo "${CURRENT_EXTENSIONS}" | grep -qF 'dash-to-dock' || [[ "${CURRENT_LAYOUT}" == "':minimize,maximize,close'" ]]; then
        CURRENT_STATE="enabled"
    else
        CURRENT_STATE="disabled"
    fi

    echo "Bluefin GNOME customizations are currently: ${CURRENT_STATE}"
    echo ""

    if [[ "${CURRENT_STATE}" == "enabled" ]]; then
        gum confirm "Disable all Bluefin GNOME customizations?" || exit 0

        echo "Disabling Bluefin GNOME customizations..."

        # Disable all Bluefin extensions
        gsettings set org.gnome.shell enabled-extensions "@as []"

        # Revert window button layout (remove minimize/maximize buttons)
        gsettings set org.gnome.desktop.wm.preferences button-layout "appmenu:close"

        # Revert monospace font to GNOME upstream default
        gsettings set org.gnome.desktop.interface monospace-font-name "Monospace 11"

        # Revert interface settings to GNOME upstream defaults
        gsettings set org.gnome.desktop.interface clock-show-weekday false
        gsettings set org.gnome.desktop.interface enable-hot-corners false
        gsettings set org.gnome.desktop.interface font-antialiasing "grayscale"
        gsettings set org.gnome.desktop.interface accent-color "default"

        # Revert window manager settings
        gsettings set org.gnome.mutter center-new-windows false

        # Revert sound settings
        gsettings set org.gnome.desktop.sound allow-volume-above-100-percent false

        echo ""
        echo "Bluefin GNOME customizations disabled."
        echo "Log out and log back in for all changes to take effect."
    else
        gum confirm "Enable all Bluefin GNOME customizations?" || exit 0

        echo "Enabling Bluefin GNOME customizations..."

        # Reset user-level overrides so system Bluefin defaults take effect
        gsettings reset org.gnome.shell enabled-extensions
        gsettings reset org.gnome.desktop.wm.preferences button-layout
        gsettings reset org.gnome.desktop.interface monospace-font-name
        gsettings reset org.gnome.desktop.interface clock-show-weekday
        gsettings reset org.gnome.desktop.interface enable-hot-corners
        gsettings reset org.gnome.desktop.interface font-antialiasing
        gsettings reset org.gnome.desktop.interface accent-color
        gsettings reset org.gnome.mutter center-new-windows
        gsettings reset org.gnome.desktop.sound allow-volume-above-100-percent

        echo ""
        echo "Bluefin GNOME customizations enabled."
        echo "Log out and log back in for all changes to take effect."
    fi
