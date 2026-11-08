#!/usr/bin/env bash
#
# fresh-install.sh — Ubuntu 26.04 Fresh Install Bootstrap
#
# Takes a bare Ubuntu Server ISO install and turns it into a tuned,
# minimal desktop in one pass. Designed for SSD installs.
#
# What it does:
#   1. Installs ubuntu-desktop-minimal (GNOME core, no bloat) with gdm3
#      Desktop decision (2026-09): GNOME on Wayland via gdm3; i3 remains
#      available as an X session. Replaces the former elementary Pantheon
#      / lightdm stack used before the elementaryOS -> Ubuntu migration.
#   2. Runs ubuntu-debloat.sh (snap removal, bloat purge, tool install)
#   3. Runs system-tune.sh (services, sysctl, ZRAM, I/O scheduler)
#   4. SSD-specific: enables fstrim timer, sets noatime, configures GRUB
#
# Usage:
#   sudo ./fresh-install.sh                    # Full fresh-install workflow
#   sudo ./fresh-install.sh --dry-run          # Preview only
#   sudo ./fresh-install.sh --skip-debloat     # Skip package debloat
#   sudo ./fresh-install.sh --skip-tune        # Skip system tuning
#

set -euo pipefail

VERSION="1.0.0"
DRY_RUN=false
SKIP_DEBLOAT=false
SKIP_TUNE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────────────────────────────
# Utility functions
# ──────────────────────────────────────────────

log_info()  { printf "  [INFO]  %s\n" "$1"; }
log_ok()    { printf "  [OK]    %s\n" "$1"; }
log_warn()  { printf "  [WARN]  %s\n" "$1" >&2; }
log_error() { printf "  [ERROR] %s\n" "$1" >&2; exit 1; }
log_dry()   { printf "  [DRY]   %s\n" "$1"; }

heading() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
    fi
}

check_companion_scripts() {
    local missing=()
    if ! $SKIP_DEBLOAT && [[ ! -x "$SCRIPT_DIR/ubuntu-debloat.sh" ]]; then
        missing+=("ubuntu-debloat.sh")
    fi
    if ! $SKIP_TUNE && [[ ! -x "$SCRIPT_DIR/system-tune.sh" ]]; then
        missing+=("system-tune.sh")
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing companion scripts in $SCRIPT_DIR: ${missing[*]}"
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "${file}.freshbak" ]]; then
        cp "$file" "${file}.freshbak"
        log_info "Backed up $file → ${file}.freshbak"
    fi
}

# ──────────────────────────────────────────────
# Step 1: Install minimal desktop
# ──────────────────────────────────────────────

install_minimal_desktop() {
    heading "Step 1: Install Minimal Desktop"

    # Detect if we're on a bare server install (no desktop)
    local has_desktop=false
    if dpkg -s ubuntu-desktop-minimal &>/dev/null 2>&1; then
        has_desktop=true
    fi

    if $has_desktop; then
        log_ok "ubuntu-desktop-minimal already installed"
        return
    fi

    if $DRY_RUN; then
        log_dry "Would run: apt update"
        log_dry "Would run: apt install -y --no-install-recommends ubuntu-desktop-minimal"
        log_dry "Would run: apt install -y --no-install-recommends ubuntu-standard"
        return
    fi

    log_info "Updating package lists..."
    apt update

    log_info "Installing ubuntu-desktop-minimal (GNOME core, no bloat)..."
    # gdm3 is explicit: it replaces the lightdm/elementary-greeter stack of the
    # former elementaryOS install (2026-09 desktop decision, see GUIDE.md).
    apt install -y --no-install-recommends gdm3 ubuntu-desktop-minimal

    log_info "Ensuring base utilities..."
    apt install -y --no-install-recommends ubuntu-standard

    log_ok "Minimal desktop installed"
    log_info "You may want to install additional packages:"
    log_info "  apt install --no-install-recommends gnome-tweaks gnome-software synaptic"
}

# ──────────────────────────────────────────────
# Step 2: Run debloat script
# ──────────────────────────────────────────────

run_debloat() {
    heading "Step 2: Remove Bloat Packages"

    if $SKIP_DEBLOAT; then
        log_info "Skipping debloat step (--skip-debloat)"
        return
    fi

    local debloat="$SCRIPT_DIR/ubuntu-debloat.sh"

    if $DRY_RUN; then
        log_dry "Would execute: $debloat (with --dry-run)"
        "$debloat" --dry-run
        return
    fi

    log_info "Running ubuntu-debloat.sh..."
    if ! "$debloat"; then
        log_warn "ubuntu-debloat.sh exited with errors — continuing anyway"
    fi
    log_ok "Debloat completed"
}

# ──────────────────────────────────────────────
# Step 3: Run system tuning
# ──────────────────────────────────────────────

run_system_tune() {
    heading "Step 3: System Performance Tuning"

    if $SKIP_TUNE; then
        log_info "Skipping system tuning step (--skip-tune)"
        return
    fi

    local tune="$SCRIPT_DIR/system-tune.sh"

    if $DRY_RUN; then
        log_dry "Would execute: $tune (with --dry-run)"
        "$tune" --dry-run
        return
    fi

    log_info "Running system-tune.sh..."
    if ! "$tune"; then
        log_warn "system-tune.sh exited with errors — continuing anyway"
    fi
    log_ok "System tuning completed"
}

# ──────────────────────────────────────────────
# Step 4: SSD-specific optimizations
# ──────────────────────────────────────────────

optimize_ssd() {
    heading "Step 4: SSD Optimizations"

    if $DRY_RUN; then
        log_dry "Would enable fstrim.timer (weekly TRIM)"
        log_dry "Would add noatime to /etc/fstab for /"
        log_dry "Would set GRUB_TIMEOUT=3 in /etc/default/grub"
        return
    fi

    # --- fstrim timer ---
    if systemctl list-unit-files fstrim.timer &>/dev/null; then
        if ! systemctl is-enabled fstrim.timer &>/dev/null; then
            systemctl enable --now fstrim.timer
            log_ok "Enabled fstrim.timer (weekly SSD TRIM)"
        else
            log_ok "fstrim.timer already enabled"
        fi
    else
        log_warn "fstrim.timer not available — install util-linux"
    fi

    # --- noatime mount option ---
    local fstab="/etc/fstab"
    if [[ -f "$fstab" ]]; then
        backup_file "$fstab"
        # Add noatime to root partition if not already present
        local root_entry
        root_entry=$(awk '$2 == "/" {print}' "$fstab" 2>/dev/null || true)
        if [[ -n "$root_entry" ]] && ! echo "$root_entry" | grep -q "noatime"; then
            # Replace the options field (4th field) with noatime added
            sed -i '/ \/ / s/\(defaults\)/\1,noatime/' "$fstab"
            log_ok "Added noatime to / mount in $fstab"
            log_info "  (will take effect after reboot)"
        else
            log_ok "noatime already set on / mount"
        fi
    fi

    # --- GRUB: faster boot ---
    local grub_file="/etc/default/grub"
    if [[ -f "$grub_file" ]]; then
        backup_file "$grub_file"
        # Reduce GRUB timeout from 10s to 3s
        if grep -q '^GRUB_TIMEOUT=' "$grub_file"; then
            sed -i 's/^GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=3/' "$grub_file"
        else
            echo 'GRUB_TIMEOUT=3' >> "$grub_file"
        fi
        update-grub 2>/dev/null || log_warn "update-grub failed — run manually"
        log_ok "Set GRUB_TIMEOUT=3 for faster boot"
    fi

    # --- I/O scheduler check ---
    local scheduler
    for dev in /sys/block/sd* /sys/block/nvme*; do
        [[ -d "$dev" ]] || continue
        local devname
        devname=$(basename "$dev")
        if [[ -r "$dev/queue/scheduler" ]]; then
            scheduler=$(cat "$dev/queue/scheduler")
            log_info "I/O scheduler for $devname: $scheduler"
        fi
    done

    log_ok "SSD optimizations applied"
}

# ──────────────────────────────────────────────
# Step 5: Install Flatpak (snap alternative)
# ──────────────────────────────────────────────

setup_flatpak() {
    heading "Step 5: Flatpak Setup"

    if $DRY_RUN; then
        log_dry "Would install flatpak, gnome-software-plugin-flatpak"
        log_dry "Would add flathub remote"
        return
    fi

    if pkg_installed flatpak; then
        log_ok "Flatpak already installed"
    else
        apt install -y flatpak
        log_ok "Installed flatpak"
    fi

    if pkg_installed gnome-software-plugin-flatpak; then
        log_ok "GNOME Software Flatpak plugin already installed"
    else
        apt install -y --no-install-recommends gnome-software-plugin-flatpak 2>/dev/null || true
        log_ok "Installed GNOME Software Flatpak plugin"
    fi

    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        log_ok "Added flathub remote"
    else
        log_ok "flathub remote already configured"
    fi
}

# ──────────────────────────────────────────────
# Step 6: Default shell -> zsh + history-expiry cron
# ──────────────────────────────────────────────

set_default_shell() {
    heading "Step 6: Set zsh as default shell"

    if ! command -v zsh &>/dev/null; then
        log_warn "zsh not found (expected via packages.sh) — installing..."
        apt install -y --no-install-recommends zsh >/dev/null
    fi

    local USER_NAME="${SUDO_USER:-jonathan}"

    if $DRY_RUN; then
        log_dry "Would run: usermod -s $(command -v zsh) ${USER_NAME}"
        log_dry "Would install cron: @daily /home/${USER_NAME}/bin/expire-history.sh"
        return
    fi

    usermod -s "$(command -v zsh)" "${USER_NAME}"
    log_ok "Default shell for ${USER_NAME} -> $(command -v zsh)"

    # Daily history expiry (see ~/bin/expire-history.sh + ~/.zshrc)
    printf 'SHELL=/bin/bash\n@daily /home/%s/bin/expire-history.sh\n' "${USER_NAME}" \
        | crontab -u "${USER_NAME}" -
    log_ok "Installed daily history-expiry cron for ${USER_NAME}"
}

# ──────────────────────────────────────────────
# Package check helper
# ──────────────────────────────────────────────

pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

# ──────────────────────────────────────────────
# Final summary
# ──────────────────────────────────────────────

print_summary() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  Fresh Install — Complete"
    echo "══════════════════════════════════════════════"
    echo ""
    echo "  What was done:"
    $SKIP_DEBLOAT || echo "  ✓ Package debloat (ubuntu-debloat.sh)"
    $SKIP_TUNE     || echo "  ✓ System tuning (system-tune.sh)"
    echo "  ✓ Minimal desktop (ubuntu-desktop-minimal)"
    echo "  ✓ SSD optimizations (fstrim, noatime, GRUB)"
    echo "  ✓ Flatpak + Flathub configured"
    echo "  ✓ Default shell set to zsh (+ daily history-expiry cron)"
    echo ""
    echo "  Post-install recommendations:"
    echo "    1. Reboot:   sudo reboot"
    echo "    2. Verify:   swapon --show, systemctl status fstrim.timer"
    echo "    3. Install apps via Flatpak:"
    echo "       flatpak install flathub org.mozilla.firefox"
    echo "       flatpak install flathub com.visualstudio.code"
    echo ""
    echo "  All scripts are in: $SCRIPT_DIR"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--dryrun)
                DRY_RUN=true
                ;;
            --skip-debloat)
                SKIP_DEBLOAT=true
                ;;
            --skip-tune)
                SKIP_TUNE=true
                ;;
            --help|-h)
                echo "Usage: sudo $0 [options]"
                echo ""
                echo "Bootstraps a fresh Ubuntu Server install into a tuned minimal desktop."
                echo ""
                echo "Options:"
                echo "  --dry-run       Preview changes without applying"
                echo "  --skip-debloat  Skip package debloat step"
                echo "  --skip-tune     Skip system tuning step"
                echo "  --help          Show this help"
                exit 0
                ;;
        esac
    done

    check_root
    check_companion_scripts

    echo "══════════════════════════════════════════════"
    echo "  Ubuntu 26.04 Fresh Install Bootstrap v$VERSION"
    echo "══════════════════════════════════════════════"
    echo ""
    log_info "Target: fresh SSD install from server ISO"
    log_info "Scripts dir: $SCRIPT_DIR"

    if $DRY_RUN; then
        echo ""
        echo "  DRY RUN MODE — no changes will be made"
    fi

    install_minimal_desktop
    run_debloat
    run_system_tune
    optimize_ssd
    setup_flatpak
    set_default_shell

    if ! $DRY_RUN; then
        print_summary
    else
        echo ""
        log_info "Dry run complete. No changes made."
        log_info "Run without --dry-run to apply."
    fi
}

main "$@"