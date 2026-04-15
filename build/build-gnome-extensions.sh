#!/usr/bin/bash

set -eoux pipefail

echo "::group:: Build GNOME Extensions"

# Install tooling
dnf5 -y install gcc glib2-devel meson sassc cmake dbus-devel

# Build Extensions

# AppIndicator Support
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas

# Blur My Shell
make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
unzip -o /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip -d /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas
rm -rf /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build

# Caffeine
# The Caffeine extension is built/packaged into a temporary subdirectory (tmp/caffeine/caffeine@patapon.info).
# Unlike other extensions, it must be moved to the standard extensions directory so GNOME Shell can detect it.
mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info /usr/share/gnome-shell/extensions/caffeine@patapon.info
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/caffeine@patapon.info/schemas

# Dash to Dock
make -C /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas

# GSConnect
# Patch metadata template for GNOME 50 support before meson processes it.
# The upstream project (GSConnect/gnome-shell-extension-gsconnect) has not yet
# declared GNOME 50 support in data/metadata.json.in. The patch adds "50" to
# the shell-version list; remove when upstream ships a GNOME 50-compatible release.
python3 - /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/data/metadata.json.in <<'EOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
# Add "50" after the last quoted version number in the shell-version array.
# Uses a regex that matches the closing ] to avoid duplicates.
if '"50"' not in content:
    content = re.sub(r'("4[0-9]")\s*(\])', r'\1, "50"\2', content)
with open(path, "w") as f:
    f.write(content)
EOF
meson setup --prefix=/usr /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/_build
meson install -C /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/_build --skip-subprojects
# GSConnect installs schemas to /usr/share/glib-2.0/schemas and meson compiles them automatically

# Logo Menu
# xdg-terminal-exec is required for this extension as it opens up terminals using that script
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/distroshelf-helper
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/missioncenter-helper
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/logomenu@aryan_k/schemas

# Search Light
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/search-light@icedman.github.com/schemas

rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

# Patch all extension metadata.json files to declare GNOME 50 compatibility.
# This is a build-time workaround for extensions whose upstream has not yet
# published a GNOME-50-compatible release. It is idempotent: if "50" is already
# present in shell-version the file is left unchanged.
# Remove patches for individual extensions once their upstream ships support.
echo "Patching extension metadata for GNOME 50 compatibility..."
for metadata_file in /usr/share/gnome-shell/extensions/*/metadata.json; do
    python3 - "${metadata_file}" <<'EOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if "50" not in data.get("shell-version", []):
    data["shell-version"] = data.get("shell-version", []) + ["50"]
    with open(path, "w") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    print(f"  Patched {path}: added '50' to shell-version")
EOF
done

# Cleanup
dnf5 -y remove gcc glib2-devel meson sassc cmake dbus-devel
rm -rf /usr/share/gnome-shell/extensions/tmp

echo "::endgroup::"
