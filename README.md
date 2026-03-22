# bluefin-br

A custom Bluefin-based bootc operating system image for Brazilian users, built on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). This image extends Bluefin with [BigLinux Parental Controls](https://github.com/biglinux/big-parental-controls) for ECA Digital (Lei 15.211/2025) compliance, Epson printer drivers and utilities for older printers not compatible with the newer `escpr2` driver, and — as an optional variant — NVIDIA 580.xxx proprietary drivers for video cards no longer supported by the 590.xxx drivers.

This image uses the **multi-stage build architecture** from @projectbluefin/distroless, combining resources from multiple OCI containers for modularity and maintainability. See the [Architecture](#architecture) section below for details.

## What Makes bluefin-br Different?

Here are the changes from Bluefin. This image is based on [Bluefin](https://projectbluefin.io) and includes these customizations:

### Added Packages (Build-time)
- **BigLinux Parental Controls** (`big-parental-controls`): GTK4 + libadwaita parental controls suite for supervised accounts, web filtering, screen time limits, and ECA Digital age-range signaling — all local-first, no cloud required.
- **Runtime dependencies**: `python3-gobject`, `gtk4`, `libadwaita`, `malcontent`, `accountsservice`, `polkit`, `acl`, `nftables`
- **Epson Inkjet Printer Driver (ESC/P-R)** (`epson-inkjet-printer-escpr`): Legacy Epson inkjet driver for printers that are **not** compatible with the newer `escpr2` driver. Built from Epson's source RPM for compatibility with modern Fedora. See [Epson Linux support page](https://support.epson.net/linux/Printer/LSB_distribution_pages/en/escpr.php).
- **Epson Printer Utility** (`epson-printer-utility`): Graphical utility for printer maintenance tasks such as nozzle check, print head cleaning, and ink level monitoring. Installed from Epson's official binary RPM. See [Epson Linux support page](https://support.epson.net/linux/Printer/LSB_distribution_pages/en/utility.php).

### Enabled Services
- `big-parental-daemon.service` — Rust D-Bus daemon for ECA Digital age-range signaling
- `big-parental-dns-restore.service` — Restores nftables DNS rules at boot
- `big-parental-time-check.timer` — Periodic screen time enforcement
- `ecbd.service` — Epson Connect Billing Daemon, required by `epson-printer-utility`

### Optional Image Variants
- **`bluefin-br-nvidia`** / **`bluefin-br-dx-nvidia`**: Includes NVIDIA **580.xxx** proprietary kernel modules and drivers (via `akmods-nvidia-lts`). Use this variant for NVIDIA video cards that are **not** supported by the newer 590.xxx drivers (e.g., older Kepler and Maxwell GPUs dropped from the current driver series). Switch to this image with:
  ```bash
  sudo bootc switch ghcr.io/lbssousa/bluefin-br-nvidia:stable
  ```
- **`bluefin-br-nvidia-open`** / **`bluefin-br-dx-nvidia-open`**: Includes the latest NVIDIA **590.xxx** open kernel modules (via `akmods-nvidia-open`). Recommended for modern NVIDIA GPUs (Turing/Ampere/Ada/Hopper and newer) supported by the open driver.

### Configuration Changes
- Based on `ghcr.io/ublue-os/silverblue-main:latest` — identical to Bluefin's base
- `/opt` is an immutable real directory (not a symlink to `/var/opt`) so that packages installed there — such as `epson-printer-utility` — are correctly included in the image layers and deployed by bootc.

*Last updated: 2025-03-21*

## What's Included

### Build System
- Automated builds via GitHub Actions on every commit
- Awesome self hosted Renovate setup that keeps all your images and actions up to date.
- Automatic cleanup of old images (90+ days) to keep it tidy
- Pull request workflow - test changes before merging to main
  - PRs build and validate before merge
  - `main` branch builds `:stable` images
- Validates your files on pull requests so you never break a build:
  - Brewfile, Justfile, ShellCheck, Renovate config, and it'll even check to make sure the flatpak you add exists on FlatHub
- Production Grade Features
  - Container signing and SBOM Generation
  - See checklist below to enable these as they take some manual configuration

### Homebrew Integration
- Pre-configured Brewfiles for easy package installation and customization
- Includes curated collections: development tools, fonts, CLI utilities. Go nuts.
- Users install packages at runtime with `brew bundle`, aliased to premade `ujust commands`
- See [custom/brew/README.md](custom/brew/README.md) for details

### Flatpak Support
- Ship your favorite flatpaks
- Automatically installed on first boot after user setup
- See [custom/flatpaks/README.md](custom/flatpaks/README.md) for details

### ujust Commands
- User-friendly command shortcuts via `ujust`
- Pre-configured examples for app installation and system maintenance for you to customize
- See [custom/ujust/README.md](custom/ujust/README.md) for details

### Build Scripts
- Modular numbered scripts (10-, 20-, 30-) run in order
- Example scripts included for third-party repositories and desktop replacement
- Helper functions for safe COPR usage
- See [build/README.md](build/README.md) for details

## Quick Start

### 1. Create Your Repository

Click "Use this template" to create a new repository from this template.

### 2. Rename the Project

Important: Change `bluefin-br` to your repository name in these 6 files:

1. `Containerfile` (line 4): `# Name: your-repo-name`
2. `Justfile` (line 1): `export image_name := env("IMAGE_NAME", "your-repo-name")`
3. `README.md` (line 1): `# your-repo-name`
4. `artifacthub-repo.yml` (line 5): `repositoryID: your-repo-name`
5. `custom/ujust/README.md` (~line 175): `localhost/your-repo-name:stable`
6. `.github/workflows/clean.yml` (line 23): `packages: your-repo-name`

### 3. Enable GitHub Actions

- Go to the "Actions" tab in your repository
- Click "I understand my workflows, go ahead and enable them"

Your first build will start automatically! 

Note: Image signing is disabled by default. Your images will build successfully without any signing keys. Once you're ready for production, see "Optional: Enable Image Signing" below.

### 4. Customize Your Image

Choose your base image in `Containerfile` (line 23):
```dockerfile
FROM ghcr.io/ublue-os/bluefin:stable
```

Add your packages in `build/10-build.sh`:
```bash
dnf5 install -y package-name
```

Customize your apps:
- Add Brewfiles in `custom/brew/` ([guide](custom/brew/README.md))
- Add Flatpaks in `custom/flatpaks/` ([guide](custom/flatpaks/README.md))
- Add ujust commands in `custom/ujust/` ([guide](custom/ujust/README.md))

### 5. Development Workflow

All changes should be made via pull requests:

1. Open a pull request on GitHub with the change you want.
3. The PR will automatically trigger:
   - Build validation
   - Brewfile, Flatpak, Justfile, and shellcheck validation
   - Test image build
4. Once checks pass, merge the PR
5. Merging triggers publishes a `:stable` image

### 6. Deploy Your Image

Switch to your image:
```bash
sudo bootc switch ghcr.io/lbssousa/bluefin-br:stable
sudo systemctl reboot
```

## Optional: Enable Image Signing

Image signing is disabled by default to let you start building immediately. However, signing is strongly recommended for production use.

### Why Sign Images?

- Verify image authenticity and integrity
- Prevent tampering and supply chain attacks
- Required for some enterprise/security-focused deployments
- Industry best practice for production images

### Setup Instructions

1. Generate signing keys:
```bash
cosign generate-key-pair
```

This creates two files:
- `cosign.key` (private key) - Keep this secret
- `cosign.pub` (public key) - Commit this to your repository

2. Add the private key to GitHub Secrets:
   - Copy the entire contents of `cosign.key`
   - Go to your repository on GitHub
   - Navigate to Settings → Secrets and variables → Actions ([GitHub docs](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository))
   - Click "New repository secret"
   - Name: `SIGNING_SECRET`
   - Value: Paste the entire contents of `cosign.key`
   - Click "Add secret"
   - If you set a password when generating the key pair, add another secret named `COSIGN_PASSWORD` with that password. If you used an empty password (just pressed Enter), this secret is not required.

3. Replace the contents of `cosign.pub` with your public key:
   - Open `cosign.pub` in your repository
   - Replace the placeholder with your actual public key
   - Commit and push the change

4. Enable signing in the workflow:
   - Edit `.github/workflows/build.yml`
   - Find the "OPTIONAL: Image Signing with Cosign" section.
   - Uncomment the steps to install Cosign and sign the image (remove the `#` from the beginning of each line in that section).
   - Commit and push the change

5. Your next build will produce signed images!

Important: Never commit `cosign.key` to the repository. It's already in `.gitignore`.

## Love Your Image? Let's Go to Production

Ready to take your custom OS to production? Enable these features for enhanced security, reliability, and performance:

### Production Checklist

- [ ] **Enable Image Signing** (Recommended)
  - Provides cryptographic verification of your images
  - Prevents tampering and ensures authenticity
  - See "Optional: Enable Image Signing" section above for setup instructions
  - Status: **Disabled by default** to allow immediate testing

- [x] **Enable SBOM Attestation** (Recommended)
  - Generates Software Bill of Materials for supply chain security
  - Provides transparency about what's in your image
  - Requires image signing to be enabled first
  - Status: **Enabled** (runs on every push to `main`)

- [x] **Enable Image Rechunking** (Recommended)
  - Optimizes bootc image layers for better update performance
  - Reduces update sizes by 5-10x
  - Improves download resumability with evenly sized layers
  - Status: **Enabled** (runs on every build)

#### Adding Image Rechunking

After building your bootc image, add a rechunk step before pushing to the registry. Here's an example based on the workflow used by [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium):

```yaml
- name: Build image
  id: build
  run: sudo podman build -t "${IMAGE_NAME}:${DEFAULT_TAG}" -f ./Containerfile .

- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 96 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"

- name: Push to Registry
  run: sudo podman push "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:${DEFAULT_TAG}"
```

Alternative approach using a temporary tag for clarity:

```yaml
- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 67 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
    
    # Tag the rechunked image with the original tag
    sudo podman tag "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked" "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"
    sudo podman rmi "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
```

**Parameters:**
- `--max-layers`: Maximum number of layers for the rechunked image (typically 67 for optimal balance)
- The first image reference is the source (input)
- The second image reference is the destination (output)
  - When using the same reference for both, the image is rechunked in-place
  - You can also use different tags (e.g., `-rechunked` suffix) and then retag if preferred

**References:**
- [CoreOS rpm-ostree build-chunked-oci documentation](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
- [bootc documentation](https://containers.github.io/bootc/)

### After Enabling Production Features

Your workflow will:
- Sign all images with your key
- Generate and attach SBOMs
- Provide full supply chain transparency

Users can verify your images with:
```bash
cosign verify --key cosign.pub ghcr.io/lbssousa/bluefin-br:stable
```

## Detailed Guides

- [Homebrew/Brewfiles](custom/brew/README.md) - Runtime package management
- [Flatpak Preinstall](custom/flatpaks/README.md) - GUI application setup
- [ujust Commands](custom/ujust/README.md) - User convenience commands
- [Build Scripts](build/README.md) - Build-time customization

## Architecture

This template follows the **multi-stage build architecture** from @projectbluefin/distroless, as documented in the [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/).

### Multi-Stage Build Pattern

**Stage 1: Context (ctx)** - Combines resources from multiple sources:
- Local build scripts (`/build`)
- Local custom files (`/custom`)
- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@projectbluefin/branding** - Branding assets
- **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite
- **@ublue-os/brew** - Homebrew integration

**Stage 2: Base Image** - Default options:
- `ghcr.io/ublue-os/silverblue-main:latest` (Fedora-based, default)
- `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based alternative)

### Benefits of This Architecture

- **Modularity**: Compose your image from reusable OCI containers
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate automatically updates OCI tags to SHA digests
- **Consistency**: Share components across Bluefin, Aurora, and custom images

### OCI Container Resources

The template imports files from these OCI containers at build time:

```dockerfile
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

Your build scripts can access these files at:
- `/ctx/oci/base/` - Base system configuration
- `/ctx/oci/common/` - Shared desktop configuration
- `/ctx/oci/branding/` - Branding assets
- `/ctx/oci/artwork/` - Artwork files
- `/ctx/oci/brew/` - Homebrew integration files

**Note**: Renovate automatically updates `:latest` tags to SHA digests for reproducible builds.

## Local Testing

Test your changes before pushing:

```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Community

- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion](https://github.com/bootc-dev/bootc/discussions)

## Learn More

- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Video Tutorial by TesterTech](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Security

This template provides security features for production use:
- Optional SBOM generation (Software Bill of Materials) for supply chain transparency
- Optional image signing with cosign for cryptographic verification
- Automated security updates via Renovate
- Build provenance tracking

These security features are disabled by default to allow immediate testing. When you're ready for production, see the "Love Your Image? Let's Go to Production" section above to enable them.
