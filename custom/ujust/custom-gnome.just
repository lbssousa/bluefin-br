# vim: set ft=make :
######################
### custom-gnome.just
######################

# Toggle, enable, or disable all Bluefin default GNOME customizations
# Includes: minimize/maximize window buttons, fonts, enabled extensions, keybindings, and other interface settings
# Usage: ujust toggle-bluefin-gnome [toggle|enable|disable]
[group('System')]
toggle-bluefin-gnome ACTION="toggle":
    #!/usr/bin/env bash
    set -euo pipefail

    ACTION="{{ ACTION }}"

    _disable_bluefin_gnome() {
        echo "Disabling Bluefin GNOME customizations..."

        # Extensions: disable all Bluefin extensions
        gsettings set org.gnome.shell enabled-extensions "@as []"

        # Interface: revert fonts and display settings to GNOME upstream defaults
        gsettings set org.gnome.desktop.interface clock-show-weekday false
        gsettings set org.gnome.desktop.interface font-antialiasing "grayscale"
        gsettings set org.gnome.desktop.interface font-name "Adwaita Sans 11"
        gsettings set org.gnome.desktop.interface document-font-name "Adwaita Sans 11"
        gsettings set org.gnome.desktop.interface monospace-font-name "Monospace 11"

        # Window manager: remove minimize/maximize buttons, revert titlebar font
        # An empty titlebar-font is the GNOME upstream default (means: use interface font)
        gsettings set org.gnome.desktop.wm.preferences button-layout "appmenu:close"
        gsettings set org.gnome.desktop.wm.preferences titlebar-font ""

        # Window manager keybindings: revert Bluefin-specific bindings
        gsettings set org.gnome.desktop.wm.keybindings show-desktop "@as []"
        gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab', '<Alt>F6']"
        gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Super>Tab', '<Shift><Alt>F6']"
        gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
        gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']"
        gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space', 'XF86Keyboard']"
        gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super>space', 'XF86Keyboard']"
        gsettings set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down', '<Alt>F5']"

        # Keyboard: revert numlock state
        gsettings set org.gnome.desktop.peripherals.keyboard numlock-state false

        # Power: revert power button action
        gsettings set org.gnome.settings-daemon.plugins.power power-button-action "suspend"

        # Media keys: revert Bluefin-specific bindings
        gsettings set org.gnome.settings-daemon.plugins.media-keys home "@as []"

        # File chooser: revert sort-directories-first
        gsettings set org.gtk.Settings.FileChooser sort-directories-first false
        gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first false

        # GNOME Software: restore update settings (only if schema is present)
        if gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.software$"; then
            gsettings set org.gnome.software allow-updates true
            gsettings set org.gnome.software download-updates true
            gsettings set org.gnome.software download-updates-notify true
        fi

        # Mutter/Compositor: revert window placement and display features
        gsettings set org.gnome.mutter center-new-windows false
        gsettings set org.gnome.mutter check-alive-timeout "uint32 5000"
        gsettings set org.gnome.mutter experimental-features "@as []"

        # Sound: revert volume limit
        gsettings set org.gnome.desktop.sound allow-volume-above-100-percent false

        echo ""
        echo "Bluefin GNOME customizations disabled."
        echo "Log out and log back in for all changes to take effect."
    }

    _enable_bluefin_gnome() {
        echo "Enabling Bluefin GNOME customizations..."

        # Reset all user-level overrides so system Bluefin gschema defaults take effect
        gsettings reset org.gnome.shell enabled-extensions
        gsettings reset org.gnome.desktop.interface clock-show-weekday
        gsettings reset org.gnome.desktop.interface font-antialiasing
        gsettings reset org.gnome.desktop.interface font-name
        gsettings reset org.gnome.desktop.interface document-font-name
        gsettings reset org.gnome.desktop.interface monospace-font-name
        gsettings reset org.gnome.desktop.wm.preferences button-layout
        gsettings reset org.gnome.desktop.wm.preferences titlebar-font
        gsettings reset org.gnome.desktop.wm.keybindings show-desktop
        gsettings reset org.gnome.desktop.wm.keybindings switch-applications
        gsettings reset org.gnome.desktop.wm.keybindings switch-applications-backward
        gsettings reset org.gnome.desktop.wm.keybindings switch-windows
        gsettings reset org.gnome.desktop.wm.keybindings switch-windows-backward
        gsettings reset org.gnome.desktop.wm.keybindings switch-input-source
        gsettings reset org.gnome.desktop.wm.keybindings switch-input-source-backward
        gsettings reset org.gnome.desktop.wm.keybindings unmaximize
        gsettings reset org.gnome.desktop.peripherals.keyboard numlock-state
        gsettings reset org.gnome.settings-daemon.plugins.power power-button-action
        gsettings reset org.gnome.settings-daemon.plugins.media-keys home
        gsettings reset org.gtk.Settings.FileChooser sort-directories-first
        gsettings reset org.gtk.gtk4.Settings.FileChooser sort-directories-first
        if gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.software$"; then
            gsettings reset org.gnome.software allow-updates
            gsettings reset org.gnome.software download-updates
            gsettings reset org.gnome.software download-updates-notify
        fi
        gsettings reset org.gnome.mutter center-new-windows
        gsettings reset org.gnome.mutter check-alive-timeout
        gsettings reset org.gnome.mutter experimental-features
        gsettings reset org.gnome.desktop.sound allow-volume-above-100-percent

        echo ""
        echo "Bluefin GNOME customizations enabled."
        echo "Log out and log back in for all changes to take effect."
    }

    # Checks five representative settings and returns "enabled", "disabled", or "partial".
    # "partial" means at least one key is at its Bluefin default AND at least one is at
    # its vanilla GNOME default, indicating that some settings were changed manually.
    _detect_state() {
        local layout extensions numlock center_windows volume
        local bluefin_count=0 gnome_count=0

        layout="$(gsettings get org.gnome.desktop.wm.preferences button-layout)"
        extensions="$(gsettings get org.gnome.shell enabled-extensions)"
        numlock="$(gsettings get org.gnome.desktop.peripherals.keyboard numlock-state)"
        center_windows="$(gsettings get org.gnome.mutter center-new-windows)"
        volume="$(gsettings get org.gnome.desktop.sound allow-volume-above-100-percent)"

        if [[ "${extensions}" == *'dash-to-dock'* ]]; then
            (( ++bluefin_count ))
        else
            (( ++gnome_count ))
        fi
        if [[ "${layout}" == *'minimize,maximize,close'* ]]; then
            (( ++bluefin_count ))
        else
            (( ++gnome_count ))
        fi
        if [[ "${numlock}" == "true" ]]; then
            (( ++bluefin_count ))
        else
            (( ++gnome_count ))
        fi
        if [[ "${center_windows}" == "true" ]]; then
            (( ++bluefin_count ))
        else
            (( ++gnome_count ))
        fi
        if [[ "${volume}" == "true" ]]; then
            (( ++bluefin_count ))
        else
            (( ++gnome_count ))
        fi

        if (( bluefin_count > 0 && gnome_count > 0 )); then
            echo "partial"
        elif (( bluefin_count > 0 )); then
            echo "enabled"
        else
            echo "disabled"
        fi
    }

    case "${ACTION}" in
        "toggle")
            CURRENT_STATE="$(_detect_state)"
            if [[ "${CURRENT_STATE}" == "partial" ]]; then
                echo "Bluefin GNOME customizations are in a mixed state — some settings have"
                echo "been manually changed and no longer match either Bluefin defaults or"
                echo "vanilla GNOME defaults."
                echo ""
                echo "Please choose how to proceed:"
                CHOICE="$(gum choose "enable" "disable")" || exit 0
                if [[ "${CHOICE}" == "enable" ]]; then
                    _enable_bluefin_gnome
                else
                    _disable_bluefin_gnome
                fi
            elif [[ "${CURRENT_STATE}" == "enabled" ]]; then
                echo "Bluefin GNOME customizations are currently: enabled"
                echo ""
                gum confirm "Disable all Bluefin GNOME customizations?" || exit 0
                _disable_bluefin_gnome
            else
                echo "Bluefin GNOME customizations are currently: disabled"
                echo ""
                gum confirm "Enable all Bluefin GNOME customizations?" || exit 0
                _enable_bluefin_gnome
            fi
            ;;
        "enable")
            CURRENT_STATE="$(_detect_state)"
            if [[ "${CURRENT_STATE}" == "enabled" ]]; then
                echo "Bluefin GNOME customizations are already fully enabled."
                exit 0
            fi
            if [[ "${CURRENT_STATE}" == "partial" ]]; then
                echo "Some Bluefin GNOME customizations have been manually changed."
                echo "Proceeding will restore all settings to Bluefin defaults."
                echo ""
            fi
            gum confirm "Enable all Bluefin GNOME customizations?" || exit 0
            _enable_bluefin_gnome
            ;;
        "disable")
            CURRENT_STATE="$(_detect_state)"
            if [[ "${CURRENT_STATE}" == "disabled" ]]; then
                echo "Bluefin GNOME customizations are already fully disabled."
                exit 0
            fi
            if [[ "${CURRENT_STATE}" == "partial" ]]; then
                echo "Some Bluefin GNOME customizations have been manually changed."
                echo "Proceeding will restore all settings to vanilla GNOME defaults."
                echo ""
            fi
            gum confirm "Disable all Bluefin GNOME customizations?" || exit 0
            _disable_bluefin_gnome
            ;;
        *)
            echo "Invalid action: ${ACTION}"
            echo "Usage: ujust toggle-bluefin-gnome [toggle|enable|disable]"
            exit 1
            ;;
    esac
