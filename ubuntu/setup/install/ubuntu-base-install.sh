#!/usr/bin/env bash
#
# ubuntu-base-install.sh — Full Ubuntu Base install (with optional encryption)
#
# One script that handles everything: LUKS setup, formatting, base system
# extraction, chroot configuration, GRUB installation.
#
# Usage:
#   sudo ./ubuntu-base-install.sh /dev/sdc [options]
#
# Prerequisites:
#   - Target disk must already be partitioned:
#     Without --encrypt: one partition (sdX1 = /)
#     With    --encrypt: two partitions (sdX1 = /boot, sdX2 = LUKS)
#
# Examples:
#   sudo ./ubuntu-base-install.sh /dev/sdc --hostname mybox --user me --password "pass"
#   sudo ./ubuntu-base-install.sh /dev/sdc --encrypt --hostname mybox --password "pass"
#   sudo ./ubuntu-base-install.sh /dev/sdc     # prompts for passwords interactively
#

set -euo pipefail

VERSION="1.0.0"

# ──────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────
DISK=""
HOSTNAME="ubuntu-ssd"
USERNAME="${LOGIN_USER:-jonathan}"  # --user, or LOGIN_USER from ubuntu/lib/host.sh
TIMEZONE=""
PASSWORD=""
LUKS_PASSWORD=""
ENCRYPT=false
PARTITION=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROOT_SCRIPT="ubuntu-base-chroot.sh"
TARBALL_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-amd64.tar.gz"
TARBALL_FILE="ubuntu-base-26.04-base-amd64.tar.gz"

# ──────────────────────────────────────────────
# Utility functions
# ──────────────────────────────────────────────
log_info()  { printf "  [INFO]  %s\n" "$1"; }
log_ok()    { printf "  [OK]    %s\n" "$1"; }
log_warn()  { printf "  [WARN]  %s\n" "$1" >&2; }
log_error() { printf "  [ERROR] %s\n" "$1" >&2; exit 1; }

heading() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════"
}

prompt_password() {
    local label="$1"
    local pass1 pass2
    while true; do
        read -s -p "  Enter password for $label: " pass1
        echo ""
        read -s -p "  Confirm password for $label: " pass2
        echo ""
        if [[ "$pass1" == "$pass2" && -n "$pass1" ]]; then
            echo "$pass1"
            return 0
        fi
        echo "  Passwords do not match or are empty. Try again."
    done
}

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: sudo $(basename "$0") DISK [options]

Full Ubuntu Base install with optional LUKS encryption.
Handles: LUKS setup, formatting, base system extraction, chroot configuration,
package installation, GRUB.

Prerequisites:
  Target disk must already be partitioned:
    Without --encrypt: one partition  (DISK1 = /)
    With    --encrypt: two partitions (DISK1 = 1G /boot, DISK2 = LUKS /)

Arguments:
  DISK            Target disk device (required, e.g. /dev/sdc)

Options:
  --encrypt       Enable LUKS full-disk encryption
  --hostname      Hostname (default: ubuntu-ssd)
  --user          Username to create (default: jonathan)
  --timezone      Timezone (default: auto-detect)
  --password      Password for root + user accounts
  --luks-password  LUKS encryption passphrase (defaults to --password if omitted)
  --partition     Partition the disk automatically (destroys all data!)
  --help, -h      Show this help

Examples:
  # Full auto: partition + LUKS + install
  sudo $(basename "$0") /dev/sdc --partition --encrypt --password "mypass"

  # Partition + plain install
  sudo $(basename "$0") /dev/sdc --partition --password "mypass"

  # Manually partitioned, different LUKS and login passwords
  sudo $(basename "$0") /dev/sdc --encrypt --luks-password "disk-key" --password "login-pass"

  # All prompted interactively, disk already partitioned
  sudo $(basename "$0") /dev/sdc --encrypt
EOF
    exit 0
}

# ──────────────────────────────────────────────
# Parse arguments
# ──────────────────────────────────────────────
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    # Positional DISK only if first arg doesn't start with --
    if [[ "$1" != --* ]]; then
        DISK="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --encrypt)
                ENCRYPT=true
                shift
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --user)
                USERNAME="$2"
                shift 2
                ;;
            --timezone)
                TIMEZONE="$2"
                shift 2
                ;;
            --password)
                PASSWORD="$2"
                shift 2
                ;;
            --luks-password)
                LUKS_PASSWORD="$2"
                shift 2
                ;;
            --partition)
                PARTITION=true
                shift
                # If next arg exists and isn't a flag, treat it as the disk
                if [[ $# -gt 0 && "$1" != --* ]]; then
                    DISK="$1"
                    shift
                fi
                ;;
            --help|-h)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$DISK" ]]; then
        log_error "No disk specified. Use: $0 /dev/sdX or $0 --partition /dev/sdX"
    fi
}

# ──────────────────────────────────────────────
# Step 0: Partition disk
# ──────────────────────────────────────────────
partition_disk() {
    if ! $PARTITION; then
        return
    fi

    heading "Step 0: Partition $DISK"

    log_warn "This will DESTROY ALL DATA on $DISK!"
    echo ""
    printf "  Proceed? [y/N] "
    local confirm
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_error "Aborted by user"
    fi

    if $ENCRYPT; then
        # Two partitions: 1G /boot (ext4, bootable) + rest (LUKS)
        log_info "Creating partitions: ${DISK}1=1G /boot, ${DISK}2=rest LUKS..."
        fdisk "$DISK" << EOF
o
n
p
1

+1G
n
p
2


a
1
w
EOF
    else
        # Single partition: whole disk (bootable)
        log_info "Creating single partition on $DISK..."
        fdisk "$DISK" << EOF
o
n
p
1


a
1
w
EOF
    fi
    log_ok "Partitioning complete"

    # Wait for kernel to re-read partition table
    sleep 1
    partprobe "$DISK" 2>/dev/null || udevadm settle 2>/dev/null || true
}

# ──────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────
validate_disk() {
    if [[ ! -b "$DISK" ]]; then
        log_error "Disk not found: $DISK"
    fi

    # Determine partition names (they may not exist yet if --partition was used)
    PART1="${DISK}1"
    # Handle nvme names like /dev/nvme0n1p1
    if [[ "$DISK" == /dev/nvme* ]]; then
        PART1="${DISK}p1"
    fi

    if ! $PARTITION; then
        # Only check existence if we didn't just partition
        if [[ ! -b "$PART1" ]]; then
            log_error "No partition 1 found on $DISK. Run fdisk first or use --partition."
        fi
    fi

    if $ENCRYPT; then
        PART2="${DISK}2"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART2="${DISK}p2"
        fi
        if ! $PARTITION && [[ ! -b "$PART2" ]]; then
            log_error "Encryption requires two partitions. Could not find ${PART2}."
        fi
        log_info "Target partitions: $PART1 (/boot) + $PART2 (LUKS /)"
    else
        log_info "Target partition: $PART1 (/)"
    fi
}

# ──────────────────────────────────────────────
# Step 1: LUKS setup
# ──────────────────────────────────────────────
setup_luks() {
    if ! $ENCRYPT; then
        return
    fi

    heading "Step 1: Set up LUKS encryption"

    local luks_pass
    if [[ -n "$LUKS_PASSWORD" ]]; then
        luks_pass="$LUKS_PASSWORD"
        log_info "Using supplied LUKS passphrase (from --luks-password)"
    elif [[ -n "$PASSWORD" ]]; then
        luks_pass="$PASSWORD"
        log_info "Using supplied password for LUKS (shared with user accounts)"
    else
        luks_pass=$(prompt_password "LUKS encryption")
    fi

    log_info "Formatting $PART2 as LUKS..."
    printf '%s' "$luks_pass" | cryptsetup luksFormat --type luks2 --pbkdf argon2id -q "$PART2" --key-file=-
    log_ok "LUKS container created on $PART2"

    log_info "Opening LUKS container..."
    sleep 1
    printf '%s' "$luks_pass" | cryptsetup open "$PART2" cryptroot --key-file=-
    log_ok "LUKS container opened as /dev/mapper/cryptroot"
}

# ──────────────────────────────────────────────
# Step 2: Format and mount
# ──────────────────────────────────────────────
format_and_mount() {
    heading "Step 2: Format filesystems and mount"

    if $ENCRYPT; then
        # Format /boot
        log_info "Formatting $PART1 as ext4 (/boot)..."
        mkfs.ext4 -L ubuntu-boot "$PART1"
        log_ok "Boot partition formatted"

        # Format encrypted root
        log_info "Formatting /dev/mapper/cryptroot as ext4..."
        mkfs.ext4 -L ubuntu-root /dev/mapper/cryptroot
        log_ok "Root partition formatted"

        # Mount
        mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount "$PART1" /mnt/boot
        log_ok "Mounted: /dev/mapper/cryptroot → /mnt, $PART1 → /mnt/boot"
    else
        # Format root (skip if already formatted)
        local fstype
        fstype=$(blkid -s TYPE -o value "$PART1" 2>/dev/null || true)
        if [[ -z "$fstype" ]]; then
            log_info "Formatting $PART1 as ext4..."
            mkfs.ext4 -L ubuntu-root "$PART1"
        else
            log_info "$PART1 already formatted as $fstype — skipping format"
        fi

        mount "$PART1" /mnt
        log_ok "Mounted: $PART1 → /mnt"
    fi
}

# ──────────────────────────────────────────────
# Step 3: Download and extract base tarball
# ──────────────────────────────────────────────
extract_base() {
    heading "Step 3: Download and extract Ubuntu Base"

    local tarball_path="/tmp/$TARBALL_FILE"

    # Download if not present
    if [[ ! -f "$tarball_path" ]]; then
        log_info "Downloading Ubuntu Base tarball..."
        curl -Lo "$tarball_path" "$TARBALL_URL"
        log_ok "Downloaded $TARBALL_FILE"
    else
        log_info "Tarball already exists at $tarball_path — reusing"
    fi

    # Verify checksum
    log_info "Verifying checksum..."
    local expected_sha
    expected_sha=$(curl -sL "${TARBALL_URL}.SHA256SUMS" 2>/dev/null | \
        grep "ubuntu-base-26.04-base-amd64.tar.gz" | awk '{print $1}' || true)
    if [[ -n "$expected_sha" ]]; then
        local actual_sha
        actual_sha=$(sha256sum "$tarball_path" | awk '{print $1}')
        if [[ "$expected_sha" != "$actual_sha" ]]; then
            log_error "Checksum mismatch! Expected $expected_sha, got $actual_sha"
        fi
        log_ok "Checksum verified"
    else
        log_warn "Could not fetch SHA256SUMS — skipping verification"
    fi

    # Extract
    log_info "Extracting base system to /mnt..."
    tar -xzf "$tarball_path" -C /mnt
    log_ok "Base system extracted"
}

# ──────────────────────────────────────────────
# Step 4: Copy chroot script and set up mounts
# ──────────────────────────────────────────────
prepare_chroot() {
    heading "Step 4: Prepare chroot environment"

    local chroot_src="$SCRIPT_DIR/$CHROOT_SCRIPT"
    if [[ ! -f "$chroot_src" ]]; then
        log_error "Companion script not found: $chroot_src"
    fi

    cp "$chroot_src" /mnt/root/
    log_ok "Copied $CHROOT_SCRIPT to /mnt/root/"

    # Copy fresh-install scripts for post-reboot
    for s in fresh-install.sh ubuntu-debloat.sh system-tune.sh; do
        if [[ -f "$SCRIPT_DIR/$s" ]]; then
            cp "$SCRIPT_DIR/$s" /mnt/root/
        fi
    done

    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    log_ok "Chroot mounts ready (/dev, /proc, /sys)"
}

# ──────────────────────────────────────────────
# Step 5: Run chroot configuration
# ──────────────────────────────────────────────
run_chroot_config() {
    heading "Step 5: Configure system inside chroot"

    local opts=""
    opts="$opts --hostname $HOSTNAME"
    opts="$opts --user $USERNAME"
    if [[ -n "$TIMEZONE" ]]; then
        opts="$opts --timezone $TIMEZONE"
    fi
    if [[ -n "$PASSWORD" ]]; then
        opts="$opts --password \"$PASSWORD\""
    fi
    if $ENCRYPT; then
        opts="$opts --encrypt"
    fi

    log_info "Running $CHROOT_SCRIPT inside chroot..."
    log_info "Target: $DISK, hostname: $HOSTNAME, user: $USERNAME"
    echo ""

    # Run inside chroot
    chroot /mnt /root/"$CHROOT_SCRIPT" "$DISK" $opts
}

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
print_summary() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  Ubuntu Base Install — Complete"
    echo "══════════════════════════════════════════════"
    echo ""
    echo "  Disk:            $DISK"
    echo "  Encryption:      $([ "$ENCRYPT" = true ] && echo 'LUKS (yes)' || echo 'none')"
    echo "  Hostname:        $HOSTNAME"
    echo "  Username:        $USERNAME"
    echo "  Timezone:        $(cat /mnt/etc/timezone 2>/dev/null || echo 'UTC')"
    echo ""
    echo "  Next steps:"
    echo "    1. Clean up:   sudo umount -R /mnt"
    echo "    2. Reboot:     sudo reboot"
    echo "    3. After boot, run:"
    echo "       sudo ~/fresh-install.sh"
    echo ""
    echo "  NOTE: If you used encryption, you will be prompted"
    echo "  for the LUKS passphrase at boot to unlock the disk."
    echo ""
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
main() {
    parse_args "$@"

    # Must be root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
    fi

    echo "══════════════════════════════════════════════"
    echo "  Ubuntu Base Installer v$VERSION"
    echo "══════════════════════════════════════════════"
    echo ""

    validate_disk
    partition_disk
    setup_luks
    format_and_mount
    extract_base
    prepare_chroot
    run_chroot_config

    print_summary
}

main "$@"