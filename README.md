# bluefin-br

A custom Bluefin-based bootc operating system image for Brazilian users, built on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). This image extends Bluefin with [BigLinux Parental Controls](https://github.com/biglinux/big-parental-controls) for ECA Digital (Lei 15.211/2025) compliance, Epson printer drivers and utilities for older printers not compatible with the newer `escpr2` driver, and — as an optional variant — NVIDIA 580.xxx proprietary drivers for video cards no longer supported by the 590.xxx drivers.

## What Makes bluefin-br Different?

Here are the changes from Bluefin. This image is based on [Bluefin](https://projectbluefin.io) and includes these customizations:

### Added Packages (Build-time)
- **BigLinux Parental Controls** (`big-parental-controls`): GTK4 + libadwaita parental controls suite for supervised accounts, web filtering, screen time limits, and ECA Digital age-range signaling — all local-first, no cloud required.
- **Runtime dependencies**: `python3-gobject`, `gtk4`, `libadwaita`, `malcontent`, `accountsservice`, `polkit`, `acl`, `nftables`
- **Epson Inkjet Printer Driver (ESC/P-R)** (`epson-inkjet-printer-escpr`): Legacy Epson inkjet driver for printers that are **not** compatible with the newer `escpr2` driver. Built from Epson's source RPM for compatibility with modern Fedora. See [Epson Linux support page](https://support.epson.net/linux/Printer/LSB_distribution_pages/en/escpr.php).
- **Epson Printer Utility** (`epson-printer-utility`): Graphical utility for printer maintenance tasks such as nozzle check, print head cleaning, and ink level monitoring. Installed from Epson's official binary RPM. See [Epson Linux support page](https://support.epson.net/linux/Printer/LSB_distribution_pages/en/utility.php).
- **libfprint with Goodix 538d support**: Custom build of [libfprint](https://fprint.freedesktop.org/) from the [Infinytum fork](https://github.com/infinytum/libfprint/tree/unstable) that adds community-developed Goodix TLS drivers — including `goodixtls53xd` for the **Goodix 538d** fingerprint reader (USB `27c6:538d`). Replaces the system `libfprint` while preserving ABI compatibility. See also [AUR `libfprint-goodix-521d`](https://aur.archlinux.org/packages/libfprint-goodix-521d) (same fork; the package name references the 521d but the fork includes drivers for the entire Goodix TLS family: 511, 52xd, and 53xd).
- **Goodix FP Dump** (`/opt/goodix-fp-dump`): Python scripts from [goodix-fp-linux-dev/goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump) for communicating with, dumping firmware from, and reverse-engineering Goodix USB fingerprint sensors. Installed together with the [goodix-firmware](https://github.com/goodix-fp-linux-dev/goodix-firmware) submodule and a pre-built Python virtual environment containing all required dependencies (`pyusb`, `crcmod`, `python-periphery`, `spidev`, `pycryptodome`, `crccheck`). See the [Goodix Fingerprint Sensor Scripts](#goodix-fingerprint-sensor-scripts) section for usage instructions.
- **Nix Package Manager infrastructure** ([DeterminateSystems nix-installer](https://github.com/DeterminateSystems/nix-installer)): The `nix-installer` binary is baked into `/usr/libexec/nix-installer` at build time. On an immutable bootc system, `/nix` is an empty bind-mount point and the real Nix store lives in the mutable `/var/nix`. On first boot (with internet access), Nix is automatically installed via `nix-first-boot.service`. See the [Nix Package Manager](#nix-package-manager) section for details.
- **Fish shell** (`fish`): The friendly interactive shell, available alongside the system default.
- **Zsh shell** (`zsh`): The Z shell, set as the default shell for new users. Use `ujust change-shell` to switch your default shell interactively.

### Enabled Services
- `big-parental-daemon.service` — Rust D-Bus daemon for ECA Digital age-range signaling
- `big-parental-dns-restore.service` — Restores nftables DNS rules at boot
- `big-parental-time-check.timer` — Periodic screen time enforcement
- `ecbd.service` — Epson Connect Billing Daemon, required by `epson-printer-utility`
- `nix.mount` — Bind-mounts `/var/nix` → `/nix` on every boot, making the persistent Nix store available at the expected path
- `nix-first-boot.service` — Runs once on first boot (requires internet) to install Nix via the DeterminateSystems nix-installer; skipped on subsequent boots once `/var/nix/.nix-installed` exists

### Optional Image Variants
- **`bluefin-br-nvidia`** / **`bluefin-br-dx-nvidia`**: Includes NVIDIA **580.xxx** proprietary kernel modules and drivers (via `akmods-nvidia-lts`). Use this variant for NVIDIA video cards that are **not** supported by the newer 590.xxx drivers (e.g., older Kepler and Maxwell GPUs dropped from the current driver series). Switch to this image with:
  ```bash
  sudo bootc switch ghcr.io/lbssousa/bluefin-br-nvidia:stable
  ```
- **`bluefin-br-nvidia-open`** / **`bluefin-br-dx-nvidia-open`**: Includes the latest NVIDIA **590.xxx** open kernel modules (via `akmods-nvidia-open`). Recommended for modern NVIDIA GPUs (Turing/Ampere/Ada/Hopper and newer) supported by the open driver.

  After switching to any NVIDIA variant and rebooting, you must complete a **one-time Secure Boot MOK enrollment** — see the [NVIDIA Images & Secure Boot](#nvidia-images--secure-boot) section below for the full procedure.

### Configuration Changes
- Based on `ghcr.io/ublue-os/silverblue-main:latest` — identical to Bluefin's base
- `/opt` is an immutable real directory (not a symlink to `/var/opt`) so that packages installed there — such as `epson-printer-utility` — are correctly included in the image layers and deployed by bootc.

*Last updated: 2026-04-24*

## Container Image Signature Verification

### Understanding "ostree-unverified-registry" in `bootc status`

If you see `ostree-unverified-registry:` in the output of `bootc status`, this means the container registry hostname does not have a signature verification policy configured in your current environment. **This does NOT mean the image is unsigned** — our images are cryptographically signed with sigstore.

**When this appears:**
- **After ISO installation**: Normal. The live installer environment doesn't have `/etc/containers/policy.json` configured yet; policy takes effect after the first boot into the installed system.
- **After manual rebase** (without `--enforce-container-sigpolicy`): The temporary environment defaults to insecure policy.
- **Expected behavior**: Changes to `ostree-image-signed:` once policy.json is in place and you use `--enforce-container-sigpolicy`.

**To explicitly enforce signature verification:**
```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/lbssousa/bluefin-br:stable
```

**To verify our signatures are valid:**
```bash
cosign verify --key https://raw.githubusercontent.com/lbssousa/bluefin-br/main/cosign.pub \
  ghcr.io/lbssousa/bluefin-br:stable
```

---

## Available Variants & Tags

All images are published to `ghcr.io/lbssousa/<variant>:<tag>`.

### Image Variants

| Image | Description |
|---|---|
| `bluefin-br` | Base image — Bluefin with Brazilian customizations |
| `bluefin-br-dx` | Developer Experience — adds dev tools on top of the base image |
| `bluefin-br-nvidia` | Base + NVIDIA **580.xxx** proprietary drivers (for older GPUs dropped from 590.xxx) |
| `bluefin-br-dx-nvidia` | DX + NVIDIA **580.xxx** proprietary drivers |
| `bluefin-br-nvidia-open` | Base + NVIDIA **590.xxx** open kernel modules (for modern Turing/Ampere/Ada/Hopper GPUs) |
| `bluefin-br-dx-nvidia-open` | DX + NVIDIA **590.xxx** open kernel modules |

### Tags

| Tag | Description |
|---|---|
| `stable` | Latest weekly promoted stable build (updated every Tuesday) |
| `gts` | Alias for `stable` ("Guaranteed To be Stable") |
| `stable-daily` | Latest daily build from the stable base |
| `stable-NN.YYYYMMDD` | Timestamped stable build (`NN` = Fedora version, e.g. `44.20260415`) |
| `stable-YYYYMMDD` | Short timestamped stable build (e.g. `20260415`) |
| `gts-NN.YYYYMMDD` | Timestamped GTS build |
| `gts-YYYYMMDD` | Short timestamped GTS build |
| `stable-daily-NN.YYYYMMDD` | Timestamped stable-daily build |
| `stable-daily-YYYYMMDD` | Short timestamped stable-daily build |

> `NN` is the Fedora major version (currently **44**). Same-day rebuilds append a `.B` build counter (e.g. `44.20260415.1`).

## Getting Started

Switch to this image on any existing Fedora Silverblue/Bluefin system:

```bash
sudo bootc switch ghcr.io/lbssousa/bluefin-br:stable
sudo systemctl reboot
```

---

## Bluefin GNOME Customizations

This image ships all of Bluefin's standard GNOME customizations (extensions, keybindings, fonts, Dash-to-Dock, and more). You can toggle them on or off at any time without rebasing using the `ujust toggle-bluefin-gnome` recipe.

### Usage

```bash
# Auto-detect current state and flip it (interactive prompt).
# If settings are in a mixed state, you will be asked to choose enable or disable.
ujust toggle-bluefin-gnome

# Apply all Bluefin defaults (no-op if already fully enabled;
# shows a warning and proceeds if in a mixed state)
ujust toggle-bluefin-gnome enable

# Apply all vanilla GNOME defaults (no-op if already fully disabled;
# shows a warning and proceeds if in a mixed state)
ujust toggle-bluefin-gnome disable
```

### Mixed / partial state

State detection uses five representative indicator keys. When at least one key is at its Bluefin value and at least one is at its GNOME upstream default, the state is reported as **mixed** (i.e. some settings were manually changed):

- **`toggle`** — displays an explanation and prompts you to pick `enable` or `disable` explicitly via an interactive menu; no automatic flip is performed.
- **`enable`** — shows a warning that some settings were changed, then forces **all** settings to Bluefin defaults. Keys that already have their Bluefin value are silently reset (idempotent).
- **`disable`** — shows a warning that some settings were changed, then forces **all** settings to vanilla GNOME defaults. Keys already at their GNOME default are silently re-applied (idempotent).

### What is toggled

| Category | Bluefin value | GNOME upstream default |
|---|---|---|
| Extensions | Dash-to-Dock, Blur My Shell, GSConnect, AppIndicator, … | None |
| Window buttons | Minimize + Maximize + Close | Close only |
| Interface fonts | Adwaita Sans 12 / JetBrains Mono 16 | Adwaita Sans 11 / Monospace 11 |
| Font antialiasing | RGBA subpixel | Grayscale |
| Keybindings | `<Super>d` show-desktop, `<Super>e` home, `<Shift><Super>space` input source | Defaults (unbound / standard) |
| Numlock on login | On | Off |
| Power button action | Interactive (show dialog) | Suspend |
| Directories first | Yes (file chooser) | No |
| GNOME Software updates | Download disabled (managed by bootc) | Enabled |
| Mutter experimental features | Fractional scaling + XWayland native scaling | None |
| Volume above 100% | Allowed | Not allowed |
| New window centering | Yes | No |

> **Note**: Disabling sets explicit user-level overrides with vanilla GNOME values. Re-enabling clears those overrides so the system-level Bluefin defaults take effect again. Both operations are idempotent — running them again when already in the target state is safe.

---

## NVIDIA Images & Secure Boot

The `bluefin-br-nvidia` and `bluefin-br-nvidia-open` image variants include pre-built NVIDIA kernel modules. Because these out-of-tree kernel modules are signed with the Universal Blue key, they require **Secure Boot MOK (Machine Owner Key) enrollment** before the modules can load.

This is a one-time step performed after the first boot into an NVIDIA image variant.

### Which NVIDIA Image Should I Use?

| Image | Driver series | GPU generations |
|---|---|---|
| `bluefin-br-nvidia` | **580.xxx** (proprietary legacy) | Older cards dropped from 590.xxx (e.g., Kepler, some Maxwell) |
| `bluefin-br-nvidia-open` | **590.xxx** (open kernel module) | Turing, Ampere, Ada, Hopper, and newer |

If you are unsure which GPU you have, run `lspci | grep -i nvidia`. Check [NVIDIA's supported GPUs page](https://www.nvidia.com/en-us/drivers/unix/) to determine which driver series supports your card.

### Switching to an NVIDIA Image

```bash
# Proprietary legacy drivers (580.xxx) — for older GPUs
sudo bootc switch ghcr.io/lbssousa/bluefin-br-nvidia:stable

# Open kernel modules (590.xxx) — for modern GPUs
sudo bootc switch ghcr.io/lbssousa/bluefin-br-nvidia-open:stable

# Reboot to apply the switch
sudo systemctl reboot
```

You can also use the interactive `ujust toggle-nvidia` recipe to switch between base, `nvidia`, and `nvidia-open` variants.

### MOK Enrollment (one-time, required on Secure Boot systems)

After the first boot into an NVIDIA image, enroll the Universal Blue signing key so that the NVIDIA kernel modules are allowed to load:

1. **Queue the key for enrollment:**
   ```bash
   ujust enroll-secure-boot-key
   ```

2. **Reboot the system:**
   ```bash
   systemctl reboot
   ```

3. **At the blue MOK Manager screen** (UEFI firmware interface), use the *QWERTY* keyboard:
   - Select **Enroll MOK**
   - Select **Continue**
   - Select **Yes**
   - Enter the enrollment password: **`universalblue`**
   - Select **Reboot**

4. The system boots normally with the key enrolled. The NVIDIA modules will load automatically.

> **Note**: If Secure Boot is disabled in your UEFI firmware, MOK enrollment is not required and the modules will load without it.

### Verifying the NVIDIA Driver Is Loaded

After rebooting:

```bash
# Check that the NVIDIA driver module is loaded
lsmod | grep nvidia

# Verify GPU is accessible
nvidia-smi
```

If `nvidia-smi` returns GPU information, the driver is working correctly.

### Switching Back to the Base Image

```bash
sudo bootc switch ghcr.io/lbssousa/bluefin-br:stable
sudo systemctl reboot
```

---

## Nix Package Manager

This image ships with [Nix](https://nixos.org/) support using the [DeterminateSystems nix-installer](https://github.com/DeterminateSystems/nix-installer). Because bootc images have a read-only root filesystem, a bind-mount strategy is used: `/var/nix` holds the real, persistent Nix store (in the mutable `/var` partition), and a systemd mount unit (`nix.mount`) binds it to `/nix` on every boot.

### First Boot

On the first boot after installation (internet connection required), `nix-first-boot.service` automatically installs Nix into `/var/nix`. This process downloads Nix packages from `cache.nixos.org` and may take a few minutes depending on your connection speed. Once complete, a marker file is created at `/var/nix/.nix-installed` so the service is skipped on subsequent boots.

### ujust Commands

| Command | Description |
|---|---|
| `ujust nix-status` | Show whether Nix is installed, the version, and daemon status |
| `ujust nix-install` | Manually trigger Nix installation (or retry after a failed first-boot) |
| `ujust nix-uninstall` | Remove Nix using the DeterminateSystems uninstaller |

### Using Nix After Installation

After the first-boot installation completes, log out and back in (or source the profile) to start using the `nix` command:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Checking Installation Progress

If the first-boot install is taking a while, you can follow the logs:

```bash
journalctl -u nix-first-boot.service -f
```

---

## Changing Your Default Shell

The image ships with **bash**, **fish**, and **zsh** pre-installed. Zsh is set as the default shell for new users. You can switch your own default shell at any time using the interactive `ujust change-shell` recipe:

```bash
ujust change-shell
```

This opens an interactive menu listing all shells registered in `/etc/shells`. Select your preferred shell and authenticate with `pkexec` to apply the change. Log out and back in for the new shell to take effect.

---

## Goodix Fingerprint Sensor Scripts

The image ships the [goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump) toolkit pre-installed at `/opt/goodix-fp-dump`. It provides Python scripts for communicating with Goodix USB fingerprint sensors — useful for firmware dumping, protocol analysis, and driver development.

> **Note from upstream**: These scripts are considered experimental and unstable. They are provided for developer and researcher use.

### Prerequisites

Connect your Goodix fingerprint sensor via USB and identify its USB product ID:

```bash
sudo lsusb -vd "27c6:" | grep "idProduct"
```

The reported product ID (e.g. `538d`) determines which script to run.

### Running a Script

The required Python dependencies are pre-installed in a virtual environment at `/opt/goodix-fp-dump/.venv`. Because the scripts require direct USB access, they must be run with `sudo`.

```bash
cd /opt/goodix-fp-dump

# Run the script matching your device's USB product ID (replace "538d" with yours)
sudo .venv/bin/python3 run_538d.py
```

Available `run_*.py` scripts (one per supported sensor):

| Script | Sensor |
|---|---|
| `run_5110.py` | Goodix 5110 |
| `run_5117.py` | Goodix 5117 |
| `run_5120_spi.py` | Goodix 5120 (SPI) |
| `run_521d.py` | Goodix 521d |
| `run_532d.py` | Goodix 532d |
| `run_5385.py` | Goodix 5385 |
| `run_538d.py` | Goodix 538d |
| `run_5395.py` | Goodix 5395 |
| `run_5503.py` | Goodix 5503 |
| `run_55a4.py` | Goodix 55a4 |
| `run_55b4.py` | Goodix 55b4 |

### Firmware Files

Firmware binaries for each sensor family are located in `/opt/goodix-fp-dump/firmware/` (sourced from the [goodix-firmware](https://github.com/goodix-fp-linux-dev/goodix-firmware) submodule).

### Updating the Scripts

Because `/opt` is an immutable layer on this bootc image (by design, for reproducibility), you cannot modify the scripts in-place. If you need a newer or custom version of goodix-fp-dump, clone it to your home directory and create a separate virtual environment there:

```bash
git clone --recurse-submodules https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git ~/goodix-fp-dump
cd ~/goodix-fp-dump
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
sudo .venv/bin/python3 run_538d.py
```
