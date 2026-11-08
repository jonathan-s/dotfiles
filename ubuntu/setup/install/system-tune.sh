#!/usr/bin/env bash
#
# system-tune.sh — Ubuntu 26.04 System Optimization Module
#
# Optimizes a running Ubuntu system for lower resource usage:
#   - Disables unnecessary systemd services
#   - Applies kernel tuning (sysctl)
#   - Enables ZRAM compressed swap (systemd-zram-generator)
#   - Moves /tmp off tmpfs onto disk (RAM-backed /tmp + fast SSD = OOM risk)
#   - Configures I/O scheduler for SSDs
#   - Enables fstrim timer + noatime mount for SSD
#   - Optionally applies performance boot parameters
#
# Usage:
#   sudo ./system-tune.sh            # Apply all optimizations
#   sudo ./system-tune.sh --dry-run  # Preview changes only
#   sudo ./system-tune.sh --revert   # Undo changes (restores backups)
#

set -euo pipefail

# --- Configuration -----------------------------------------------------------

DRY_RUN=false
REVERT=false

# Systemd services to disable (can be re-enabled later if needed)
DISABLE_SERVICES=(
    bluetooth.service                # Bluetooth stack
    cups.service                     # CUPS printing daemon
    cups-browsed.service             # CUPS printer discovery
    avahi-daemon.service             # mDNS/.local discovery
    avahi-daemon.socket              # mDNS socket
    ModemManager.service             # Mobile broadband modem
    whoopsie.service                 # Error reporting
    whoopsie.path                    # Error reporting trigger
    fwupd.service                    # Firmware updater (keeps polling)
    fwupd-refresh.service            # Firmware metadata refresh timer
    pppd-dns.service                 # PPP DNS (obsolete for most)
    speech-dispatcher.service        # Text-to-speech (accessibility)
    speech-dispatcherd.socket        # TTS socket
)

# Sysctl parameters to apply
declare -A SYSCTL_PARAMS=(
    # Memory management
    ["vm.swappiness"]="10"                    # Use RAM aggressively, swap only as fallback
    ["vm.vfs_cache_pressure"]="50"            # Don't shrink inode/dentry cache too eagerly
    ["vm.dirty_background_ratio"]="5"         # Start writing dirty pages at 5%
    ["vm.dirty_ratio"]="10"                   # Force write at 10% dirty pages
    ["vm.min_free_kbytes"]="65536"            # Keep 64MB free for emergency allocations
    ["vm.page-cluster"]="0"                   # Disable multi-page swap I/O (ZRAM is fast)

    # Network tuning
    ["net.core.rmem_default"]="262144"        # Default receive buffer
    ["net.core.wmem_default"]="262144"        # Default send buffer
    ["net.ipv4.tcp_congestion_control"]="bbr" # BBR congestion control (kernel 5.9+)
    ["net.core.default_qdisc"]="fq"           # Fair queueing for BBR

    # Kernel behavior
    ["kernel.nmi_watchdog"]="0"               # Disable NMI watchdog (saves power/CPU)
    ["kernel.random.read_wakeup_threshold"]="64"
    ["kernel.random.write_wakeup_threshold"]="128"
    ["fs.inotify.max_user_watches"]="524288"  # More file watchers (needed for IDEs)
)

# ZRAM configuration — via systemd-zram-generator
# zram-size is a plain MiB number. Unit suffixes ("2G") are NOT supported:
# the generator evaluates the value with fasteval, so "2G" becomes a bogus
# huge size and the kernel returns "Cannot allocate memory" on disksize.
ZRAM_SIZE_MB=2048                 # ~25% of this machine's 7.7G RAM (tunable)
ZRAM_ALGORITHM="zstd"             # Compression algorithm: lzo, lzo-rle, lz4, zstd, deflate
ZRAM_SWAP_PRIORITY=100            # swap priority (higher = preferred)

# --- Helper Functions --------------------------------------------------------

info()  { printf "  [INFO]  %s\n" "$*"; }
warn()  { printf "  [WARN]  %s\n" "$*" >&2; }
ok()    { printf "  [OK]    %s\n" "$*"; }
skip()  { printf "  [SKIP]  %s\n" "$*"; }
dry()   { printf "  [DRY]   %s\n" "$*"; }
fail()  { printf "  [FAIL]  %s\n" "$*" >&2; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "This script must be run as root (sudo)."
    fi
}

has_command() {
    command -v "$1" &>/dev/null
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "${file}.sysbak" ]]; then
        cp "$file" "${file}.sysbak"
        info "Backed up $file → ${file}.sysbak"
    fi
}

restore_file() {
    local file="$1"
    if [[ -f "${file}.sysbak" ]]; then
        cp "${file}.sysbak" "$file"
        ok "Restored $file from backup"
    fi
}

# --- Systemd Service Tuning -------------------------------------------------

tune_services() {
    echo ""
    echo "========================================"
    echo "  Step 1: Disable Unnecessary Services"
    echo "========================================"

    local disabled_count=0
    local skipped_count=0

    for svc in "${DISABLE_SERVICES[@]}"; do
        if $DRY_RUN; then
            dry "Would disable: $svc"
            continue
        fi

        # Check if service exists
        if systemctl list-units --all -t service,socket,path --no-legend 2>/dev/null | \
           awk '{print $1}' | grep -qxF "$svc"; then
            if systemctl is-enabled "$svc" &>/dev/null; then
                systemctl disable --now "$svc" 2>/dev/null || true
                ok "Disabled: $svc"
                ((disabled_count++))
            else
                skip "$svc is already disabled"
                ((skipped_count++))
            fi
        else
            skip "$svc not found"
            ((skipped_count++))
        fi
    done

    echo ""
    info "Services: $disabled_count disabled, $skipped_count skipped/already off"
}

# --- Kernel Sysctl Tuning ---------------------------------------------------

tune_sysctl() {
    echo ""
    echo "========================================"
    echo "  Step 2: Apply Kernel Parameters"
    echo "========================================"

    local sysctl_conf="/etc/sysctl.d/99-ubuntu-tune.conf"

    if $DRY_RUN; then
        dry "Would create: $sysctl_conf"
        for key in "${!SYSCTL_PARAMS[@]}"; do
            dry "  $key = ${SYSCTL_PARAMS[$key]}"
        done
        return
    fi

    backup_file "$sysctl_conf"

    # Write new config
    {
        echo "# Ubuntu Tuning — generated by system-tune.sh on $(date -I)"
        echo "#"
        for key in "${!SYSCTL_PARAMS[@]}"; do
            echo "$key = ${SYSCTL_PARAMS[$key]}"
        done
    } > "$sysctl_conf"

    # Apply immediately
    sysctl --system &>/dev/null
    ok "Applied kernel parameters from $sysctl_conf"

    # Verify key settings
    local applied
    applied=$(sysctl vm.swappiness 2>/dev/null | awk '{print $3}')
    info "vm.swappiness is now: $applied (target: ${SYSCTL_PARAMS[vm.swappiness]})"
}

# --- ZRAM Setup -------------------------------------------------------------

tune_zram() {
    echo ""
    echo "========================================"
    echo "  Step 3: Configure ZRAM"
    echo "========================================"

    if $DRY_RUN; then
        dry "Would enable ZRAM (${ZRAM_ALGORITHM}, ${ZRAM_SIZE_MB}MB, priority ${ZRAM_SWAP_PRIORITY})"
        return
    fi

    # Check if ZRAM kernel module is available
    if ! modprobe -n zram 2>/dev/null; then
        warn "ZRAM kernel module not available; skipping"
        return
    fi

    # Check if ZRAM is already active
    if grep -q zram /proc/swaps 2>/dev/null; then
        skip "ZRAM is already active"
        return
    fi

    # Use systemd-zram-generator: it runs as a system generator at every boot
    # (creates the device, formats swap, activates it), so ZRAM survives
    # reboots with no extra service to manage.
    if [[ ! -x /usr/lib/systemd/system-generators/zram-generator ]]; then
        info "Installing systemd-zram-generator..."
        apt-get install -y systemd-zram-generator
    fi

    # IMPORTANT: zram-size is evaluated with fasteval, which has no unit
    # support. "2G" parses as a bogus huge value and the kernel returns
    # "Cannot allocate memory" when setting disksize. Use a plain MiB number.
    local zram_conf="/etc/systemd/zram-generator.conf"
    backup_file "$zram_conf"
    cat > "$zram_conf" << EOF
# ZRAM swap — generated by system-tune.sh
# NOTE: zram-size must be a plain MiB number; unit suffixes are NOT parsed.
[zram0]
zram-size = ${ZRAM_SIZE_MB}
compression-algorithm = ${ZRAM_ALGORITHM}
swap-priority = ${ZRAM_SWAP_PRIORITY}
EOF

    systemctl daemon-reload
    systemctl start dev-zram0.swap 2>/dev/null || true

    ok "ZRAM enabled: ${ZRAM_SIZE_MB}MB ${ZRAM_ALGORITHM}-compressed swap"
    info  "Verify with: zramctl, swapon --show"
}

# --- /tmp off tmpfs ---------------------------------------------------------

tune_tmp() {
    echo ""
    echo "========================================"
    echo "  Step 4: Move /tmp off tmpfs onto Disk"
    echo "========================================"

    if $DRY_RUN; then
        dry "Would mask tmp.mount (keep /tmp on the root disk, not RAM)"
        return
    fi

    # Not present on all installs
    if [[ ! -e /usr/lib/systemd/system/tmp.mount ]]; then
        skip "tmp.mount not present (no tmpfs /tmp)"
        return
    fi

    # systemd mounts /tmp as tmpfs (RAM) by default. On a fast SSD the old
    # speed rationale is gone, and RAM-backed /tmp lets builds (cargo, etc.)
    # grow straight into RAM with no swap fallback → OOM.
    if systemctl is-enabled tmp.mount 2>/dev/null | grep -q "masked"; then
        skip "tmp.mount already masked (/tmp on disk)"
        return
    fi

    # If /tmp is currently a tmpfs, move its contents to disk first.
    if grep ' /tmp ' /proc/mounts | grep -q tmpfs; then
        info "Moving existing /tmp (tmpfs) contents onto disk..."
        local preserve="/var/tmp/tmp-preserve-$$"
        mkdir -p "$preserve"
        if has_command rsync; then
            rsync -a /tmp/ "$preserve/"
        else
            cp -a /tmp/. "$preserve/"
        fi
        umount -l /tmp 2>/dev/null || true
        if has_command rsync; then
            rsync -a "$preserve/" /tmp/
        else
            cp -a "$preserve/." /tmp/
        fi
        rm -rf "$preserve"
        ok "Moved /tmp contents to disk and detached the tmpfs"
    fi

    systemctl mask tmp.mount
    ok "Masked tmp.mount — /tmp now lives on the root disk"
    info  "Verify with: df -h /tmp (should show /dev/…, not tmpfs)"
}

# --- I/O Scheduler for SSD --------------------------------------------------

tune_iosched() {
    echo ""
    echo "========================================"
    echo "  Step 5: Configure I/O Scheduler"
    echo "========================================"

    local udev_rule="/etc/udev/rules.d/60-ssd-scheduler.rules"

    if $DRY_RUN; then
        dry "Would create: $udev_rule (set SSD scheduler to 'none')"
        return
    fi

    backup_file "$udev_rule"

    # Set scheduler for SSD/NVMe devices via udev rule
    cat > "$udev_rule" << 'UDEV'
# Set I/O scheduler for SSDs and NVMe — generated by system-tune.sh
# "none" gives best performance on modern SSDs/NVMe
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
UDEV

    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --type=devices --action=change 2>/dev/null || true

    ok "I/O scheduler udev rule installed: $udev_rule"
    info "SSDs and NVMe devices will use the 'none' scheduler"
}

# --- SSD-Specific Optimizations ----------------------------------------------

tune_ssd() {
    echo ""
    echo "========================================"
    echo "  Step 6: SSD-Specific Optimizations"
    echo "========================================"

    if $DRY_RUN; then
        dry "Would enable fstrim.timer (weekly TRIM)"
        dry "Would add noatime to /etc/fstab"
        return
    fi

    # --- fstrim timer ---
    if systemctl list-unit-files fstrim.timer &>/dev/null 2>&1; then
        if ! systemctl is-enabled fstrim.timer &>/dev/null 2>&1; then
            systemctl enable --now fstrim.timer 2>/dev/null || true
            ok "Enabled fstrim.timer (weekly SSD TRIM)"
        else
            skip "fstrim.timer already enabled"
        fi
    else
        warn "fstrim.timer not found — install util-linux"
    fi

    # --- noatime mount option ---
    local fstab="/etc/fstab"
    if [[ -f "$fstab" ]]; then
        backup_file "$fstab"
        local root_entry
        root_entry=$(awk '"$2" == "/" {print}' "$fstab" 2>/dev/null || true)
        if [[ -n "$root_entry" ]] && ! echo "$root_entry" | grep -q "noatime"; then
            sed -i '/ \/ / s/\(defaults\)/\1,noatime/' "$fstab"
            ok "Added noatime to / mount (will apply after reboot)"
        else
            skip "noatime already set on / or / not found"
        fi
    fi

    # --- Display current I/O scheduler ---
    echo ""
    info "Current I/O schedulers:"
    for dev in /sys/block/sd[a-z] /sys/block/nvme[0-9]*; do
        [[ -d "$dev" ]] || continue
        local name
        name=$(basename "$dev")
        if [[ -r "$dev/queue/scheduler" ]]; then
            printf "  %-8s %s\n" "$name:" "$(cat "$dev/queue/scheduler")"
        fi
    done
}

# --- Boot Parameter Recommendation ------------------------------------------

suggest_boot_params() {
    echo ""
    echo "========================================"
    echo "  Step 7: Boot Parameter Suggestions"
    echo "========================================"

    if $DRY_RUN; then
        dry "Would suggest adding boot params to /etc/default/grub"
        return
    fi

    local grub_file="/etc/default/grub"
    local params="quiet splash nowatchdog"

    if [[ -f "$grub_file" ]]; then
        echo ""
        info "Current GRUB_CMDLINE_LINUX_DEFAULT:"
        grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" 2>/dev/null || echo "  (not set)"

        echo ""
        info "Suggested boot parameters:"
        echo "  $params"
        echo ""
        info "To apply manually:"
        echo "  1. Edit /etc/default/grub:"
        echo "     GRUB_CMDLINE_LINUX_DEFAULT=\"$params\""
        echo "  2. Run: sudo update-grub"
        echo "  3. Reboot"
        echo ""
        warn "NOTE: 'nowatchdog' disables hardware watchdog timer (saves ~1-2W power)"
        warn "These changes are NOT applied automatically by this script."
    fi
}

# --- Revert All Changes -----------------------------------------------------

do_revert() {
    echo ""
    echo "========================================"
    echo "  Reverting All Changes"
    echo "========================================"

    # Restore sysctl
    local sysctl_conf="/etc/sysctl.d/99-ubuntu-tune.conf"
    if [[ -f "${sysctl_conf}.sysbak" ]]; then
        restore_file "$sysctl_conf"
        sysctl --system &>/dev/null
    else
        rm -f "$sysctl_conf"
        sysctl --system &>/dev/null
    fi
    ok "Reverted kernel parameters"

    # Restore udev rule
    local udev_rule="/etc/udev/rules.d/60-ssd-scheduler.rules"
    if [[ -f "${udev_rule}.sysbak" ]]; then
        restore_file "$udev_rule"
    else
        rm -f "$udev_rule"
    fi
    udevadm control --reload-rules 2>/dev/null || true
    ok "Reverted I/O scheduler rules"

    # Disable ZRAM (systemd-zram-generator)
    if systemctl is-active dev-zram0.swap &>/dev/null 2>&1; then
        swapoff /dev/zram0 2>/dev/null || true
        systemctl stop dev-zram0.swap 2>/dev/null || true
    fi
    if [[ -e /sys/block/zram0/reset ]]; then
        echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    fi
    local zram_conf="/etc/systemd/zram-generator.conf"
    if [[ -f "${zram_conf}.sysbak" ]]; then
        restore_file "$zram_conf"
    else
        rm -f "$zram_conf"
    fi
    systemctl daemon-reload
    ok "ZRAM disabled and removed"

    # Restore /tmp as tmpfs
    if systemctl is-enabled tmp.mount 2>/dev/null | grep -q masked; then
        systemctl unmask tmp.mount
        systemctl start tmp.mount 2>/dev/null || true
        ok "Restored /tmp as tmpfs"
    fi

    # Re-enable services (only ones that exist)
    echo ""
    info "Re-enabling services (that were previously disabled)..."
    for svc in "${DISABLE_SERVICES[@]}"; do
        systemctl enable --now "$svc" 2>/dev/null || true
    done

    echo ""
    ok "All optimizations reverted. Reboot recommended."
}

# --- Main -------------------------------------------------------------------

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--dryrun)
                DRY_RUN=true
                ;;
            --revert|--undo)
                REVERT=true
                ;;
            --help|-h)
                echo "Usage: sudo $0 [--dry-run|--revert]"
                echo ""
                echo "  --dry-run   Show what would be changed without applying"
                echo "  --revert    Undo all changes made by this script"
                exit 0
                ;;
        esac
    done

    check_root

    echo "============================================"
    echo "  Ubuntu 26.04 System Tuning"
    echo "============================================"
    echo ""

    if $DRY_RUN; then
        echo "  DRY RUN MODE — no changes will be made"
    elif $REVERT; then
        do_revert
        exit 0
    fi

    tune_services
    tune_sysctl
    tune_zram
    tune_tmp
    tune_iosched
    tune_ssd
    suggest_boot_params

    echo ""
    echo "========================================"
    echo "  Summary"
    echo "========================================"
    if $DRY_RUN; then
        echo "  Dry run complete. No changes made."
        echo "  Run without --dry-run to apply."
    else
        echo "  System tuning applied."
        echo "  A full reboot is recommended for all changes to take effect."
    fi
    echo ""
}

main "$@"