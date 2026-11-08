#!/usr/bin/env bash
# ubuntu-debloat.sh
# Comprehensive debloating script for Ubuntu 26.04 LTS
#
# Combines best practices from:
#   - github.com:matissd/ubuntu-26-debloat-script
#   - github.com:lucasgab2230/ubuntu-debloater
#   - Various community guides
#
# Usage: sudo ./ubuntu-debloat.sh
# Run with --dry-run to preview changes without making them.

set -euo pipefail

VERSION="1.0.0"
DRY_RUN=false

# ──────────────────────────────────────────────
# Utility functions
# ──────────────────────────────────────────────

log_info()  { echo "[INFO]  $1"; }
log_warn()  { echo "[WARN]  $1" >&2; }
log_ok()    { echo "[OK]    $1"; }
log_error() { echo "[ERROR] $1" >&2; exit 1; }

heading() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

confirm_or_exit() {
    local prompt="${1:-Continue?}"
    read -rp "$prompt (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) echo "Aborted."; exit 0 ;;
    esac
}

pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

pkg_is_held() {
    apt-mark showhold | grep -qx "$1"
}

run() {
    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] $*"
        return 0
    fi
    "$@"
}

# ──────────────────────────────────────────────
# Preflight checks
# ──────────────────────────────────────────────

preflight() {
    heading "Preflight Checks"

    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)."
    fi

    if ! command -v apt &>/dev/null; then
        log_error "APT package manager not found."
    fi

    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "Detected: $NAME $VERSION_ID ($ID)"
        if [ "$ID" != "ubuntu" ]; then
            log_warn "This script is designed for Ubuntu. Proceed at your own risk."
            confirm_or_exit "Continue on $ID?"
        fi
    else
        log_error "Cannot detect OS — /etc/os-release not found."
    fi

    log_info "APT package manager found."
    log_ok "Preflight checks passed."
}

# ──────────────────────────────────────────────
# Step 1: Remove Snap packages and snapd
# ──────────────────────────────────────────────

remove_snap() {
    heading "[1/6] Removing Snap packages and snapd"

    log_info "Making sure snapd socket is running (needed for clean removal)..."
    run systemctl start snapd.socket snapd.service 2>/dev/null || true
    sleep 2

    log_info "Killing active snap processes..."
    run pkill -f /snap/firefox 2>/dev/null || true
    run pkill -f /snap/ 2>/dev/null || true
    sleep 1

    log_info "Aborting stuck snap transactions..."
    for change_id in $(snap changes 2>/dev/null | awk '$2 == "Doing" {print $1}'); do
        echo "    Aborting snap change: $change_id"
        run snap abort "$change_id" 2>/dev/null || true
    done

    log_info "Removing snap applications..."
    for snap_name in \
        firefox thunderbird snap-store firmware-updater \
        desktop-security-center prompting-client snapd-desktop-integration; do
        run snap remove --purge "$snap_name" 2>/dev/null || true
    done

    log_info "Removing platform / theme / graphics snaps..."
    for s in $(snap list 2>/dev/null | awk 'NR>1 && ($1 ~ /^gnome-/ || $1 ~ /^mesa-/) {print $1}'); do
        run snap remove --purge "$s" 2>/dev/null || true
    done

    log_info "Removing base snaps..."
    for s in bare core22 core24 core26; do
        run snap remove --purge "$s" 2>/dev/null || true
    done

    log_info "Removing remaining straggler snaps..."
    for s in $(snap list 2>/dev/null | awk 'NR>1 && $1 != "snapd" {print $1}'); do
        run snap remove --purge "$s" 2>/dev/null || true
    done

    log_info "Removing snapd package..."
    run snap remove --purge snapd 2>/dev/null || true
    run systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    run systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    run apt purge -y snapd
    run apt-mark hold snapd

    log_info "Cleaning up snap directories..."
    run rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /root/snap

    log_info "Pinning snapd to prevent reinstallation..."
    run bash -c 'cat > /etc/apt/preferences.d/nosnap.pref <<- EOM
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOM'

    log_ok "Snap removed and pinned."
}

# ──────────────────────────────────────────────
# Step 2: Remove APT bloat packages
# ──────────────────────────────────────────────

remove_apt_bloat() {
    heading "[2/6] Removing unwanted APT packages"

    BLOAT_PACKAGES=(
        # Browsers (we'll install alternatives later)
        firefox

        # Mail
        thunderbird

        # Office suite
        libreoffice-common libreoffice-core libreoffice-gnome
        libreoffice-writer libreoffice-calc libreoffice-impress
        libreoffice-draw libreoffice-math libreoffice-base-core

        # Media players (Ubuntu 26.04 uses Showtime instead of Totem)
        totem totem-common showtime
        rhythmbox rhythmbox-data

        # Multimedia apps
        cheese
        simple-scan

        # BitTorrent
        transmission-gtk transmission-common

        # Games
        aisleriot gnome-mahjongg gnome-mines gnome-sudoku
        quadrapassel hitori lightsoff swell-foop

        # GNOME apps (often unused)
        gnome-contacts gnome-weather gnome-maps
        gnome-characters gnome-todo
        shotwell

        # Remote desktop
        remmina remmina-common remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret

        # Telemetry
        popularity-contest

        # Example content
        example-content
    )

    INSTALLED=()
    for pkg in "${BLOAT_PACKAGES[@]}"; do
        if pkg_installed "$pkg"; then
            INSTALLED+=("$pkg")
        fi
    done

    if [ ${#INSTALLED[@]} -eq 0 ]; then
        log_info "No bloat packages are installed. Skipping."
        return
    fi

    echo "    Packages to remove:"
    for pkg in "${INSTALLED[@]}"; do
        echo "      - $pkg"
    done
    echo ""

    if [ "$DRY_RUN" = false ]; then
        confirm_or_exit "Remove these ${#INSTALLED[@]} packages?"
    fi

    run apt purge -y "${INSTALLED[@]}" 2>/dev/null || true

    # Hold Firefox so it doesn't return as a dependency
    if ! pkg_is_held firefox; then
        run apt-mark hold firefox 2>/dev/null || true
    fi

    log_ok "Bloat packages removed."
}

# ──────────────────────────────────────────────
# Step 3: Install essential tools and apps
# ──────────────────────────────────────────────

install_tools() {
    heading "[3/6] Installing essential tools and applications"

    run apt update

    # Development essentials
    DEV_PACKAGES=(
        build-essential cmake ninja-build git ccache
        python3 python3-pip python3-venv python3-full pipx
        flex bison gperf libffi-dev libssl-dev pkg-config
        unzip xz-utils
    )

    # Clang/LLVM toolchain
    LLVM_PACKAGES=(
        clang clangd clang-format clang-tools clang-tidy lld
    )

    # USB and serial tools
    USB_PACKAGES=(
        dfu-util libusb-1.0-0 minicom picocom screen usbutils
    )

    # Desktop tools
    DESKTOP_PACKAGES=(
        gnome-tweaks gnome-software
        synaptic
        fonts-noto fonts-noto-cjk fonts-firacode
        ffmpeg
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
    )

    ALL_PACKAGES=(
        "${DEV_PACKAGES[@]}"
        "${LLVM_PACKAGES[@]}"
        "${USB_PACKAGES[@]}"
        "${DESKTOP_PACKAGES[@]}"
    )

    log_info "Installing ${#ALL_PACKAGES[@]} packages with --no-install-recommends..."
    run apt install --no-install-recommends -y "${ALL_PACKAGES[@]}"

    # Add user to dialout group for serial access
    local actual_user
    actual_user="${SUDO_USER:-$USER}"
    if [ "$actual_user" != "root" ]; then
        run usermod -aG dialout "$actual_user"
        log_info "Added '$actual_user' to 'dialout' group (effective after re-login)."
    fi

    log_ok "Tools installed."
}

# ──────────────────────────────────────────────
# Step 4: Install browser (Brave)
# ──────────────────────────────────────────────

install_browser() {
    heading "[4/6] Installing Brave browser"

    if command -v brave-browser &>/dev/null; then
        log_info "Brave browser is already installed. Skipping."
        return
    fi

    log_info "Adding Brave repository..."
    run curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | run tee /etc/apt/sources.list.d/brave-browser-release.list

    run apt update
    run apt install --no-install-recommends -y brave-browser
    log_ok "Brave browser installed."
}

# ──────────────────────────────────────────────
# Step 5: Configure GNOME settings
# ──────────────────────────────────────────────

configure_gnome() {
    heading "[5/6] Configuring GNOME desktop settings"

    # Disable middle-click paste (common annoyance)
    run gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false 2>/dev/null || true

    # Show hidden files in file manager by default
    run gsettings set org.gnome.nautilus.preferences show-hidden-files true 2>/dev/null || true

    # Disable automatic suspend when on AC power
    run gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true

    # Set dark theme (preference)
    run gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

    # Reduce title bar height
    run gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true

    log_ok "GNOME settings configured."
}

# ──────────────────────────────────────────────
# Step 6: Final cleanup
# ──────────────────────────────────────────────

final_cleanup() {
    heading "[6/6] Final cleanup"

    # Remove orphaned packages
    log_info "Removing orphaned dependencies..."
    run apt autoremove --purge -y

    # Remove residual config files
    log_info "Purging residual configuration files..."
    run dpkg -l | awk '/^rc/ {print $2}' | xargs -r dpkg --purge

    # Clean package cache
    log_info "Cleaning package cache..."
    run apt clean
    run apt autoclean

    # Vacuum journal logs older than 7 days
    log_info "Trimming system logs..."
    run journalctl --vacuum-time=7d 2>/dev/null || true

    # Clean thumbnail cache
    local actual_user="${SUDO_USER:-$USER}"
    if [ "$actual_user" != "root" ]; then
        local home_dir
        home_dir=$(getent passwd "$actual_user" | cut -d: -f6)
        run rm -rf "$home_dir/.cache/thumbnails/"* 2>/dev/null || true
    fi

    log_ok "Cleanup complete."
}

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────

print_summary() {
    heading "Summary"
    echo "  Snap:         Removed and pinned"
    echo "  APT bloat:    Purged"
    echo "  Tools:        Installed (build, dev, serial, desktop)"
    echo "  Browser:      Brave"
    echo "  GNOME:        Configured for productivity"
    echo "  Cleanup:      Orphans purged, logs trimmed, cache cleaned"
    echo ""
    echo "  To finish, reboot or re-login:"
    echo "    sudo reboot"
    echo ""
    echo "  To install VS Code after reboot:"
    echo "    # Add Microsoft repo and install"
    echo "    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null"
    echo '    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list'
    echo "    sudo apt update && sudo apt install code"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

main() {
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            --help|-h)
                echo "Usage: sudo $0 [--dry-run]"
                echo ""
                echo "  --dry-run    Preview changes without making any"
                echo "  --help, -h   Show this help"
                exit 0
                ;;
        esac
    done

    echo "┌────────────────────────────────────────────┐"
    echo "│     Ubuntu 26.04 Debloat Script v$VERSION    │"
    echo "└────────────────────────────────────────────┘"

    if [ "$DRY_RUN" = true ]; then
        echo ""
        log_warn "DRY RUN MODE — no changes will be made."
        echo ""
    fi

    preflight
    confirm_or_exit "Proceed with debloating?"

    remove_snap
    remove_apt_bloat
    install_tools
    install_browser
    configure_gnome
    final_cleanup
    print_summary

    echo ""
    log_ok "Debloating complete!"
}

main "$@"