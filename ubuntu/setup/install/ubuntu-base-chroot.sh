#!/usr/bin/env bash
#
# ubuntu-base-chroot.sh — Configure Ubuntu Base system from inside chroot
#
# Run this AFTER extracting ubuntu-base tarball, mounting /dev/proc/sys,
# and chrooting in. It sets up everything needed to boot: kernel, GRUB,
# users, networking, fstab, locale, timezone.
#
# Usage:
#   sudo mount --bind /dev /mnt/dev
#   sudo mount --bind /proc /mnt/proc
#   sudo mount --bind /sys /mnt/sys
#   sudo cp ubuntu-base-chroot.sh /mnt/root/
#   sudo chroot /mnt /root/ubuntu-base-chroot.sh /dev/sda [options]
#
# Arguments:
#   DISK         Target disk device (required, e.g. /dev/sda)
#
# Options:
#   --hostname   Hostname for the new system (default: ubuntu-ssd)
#   --user       Username to create (default: jonathan)
#   --timezone   Timezone (default: auto-detect from current system)
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
ENCRYPT=false

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") DISK [options]

Configure an Ubuntu Base chroot into a bootable system.

Arguments:
  DISK           Target disk (required, e.g. /dev/sdc)

Options:
  --hostname     Hostname (default: ubuntu-ssd)
  --user         Username (default: jonathan)
  --timezone     Timezone (default: auto-detect)
  --password    Set same password for root and user (skip interactive prompt)
  --encrypt     Configure for LUKS-encrypted root (crypttab, fstab, GRUB)
  --help, -h    Show this help

Examples:
  $(basename "$0") /dev/sdc --hostname mybox --user me --password "hunter2"
  $(basename "$0") /dev/sdc   # prompts for passwords interactively
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

    DISK="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
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
            --encrypt)
                ENCRYPT=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done
}

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
# Validation
# ──────────────────────────────────────────────
validate() {
    if [[ ! -b "$DISK" ]]; then
        log_error "Disk not found: $DISK"
    fi

    # Detect the first partition on the disk
    PART="${DISK}1"
    if [[ ! -b "$PART" ]]; then
        # Handle nvme/nvme0n1p1 style names
        PART="$(lsblk -ln -o NAME "$DISK" 2>/dev/null | sed -n '2p' | xargs -I{} echo /dev/{})"
        if [[ -z "$PART" || ! -b "$PART" ]]; then
            log_error "Could not find a partition on $DISK"
        fi
    fi

    log_info "Target disk: $DISK"

    if $ENCRYPT; then
        # Detect second partition (LUKS container)
        LUKS_PART="${DISK}2"
        if [[ ! -b "$LUKS_PART" ]]; then
            LUKS_PART="${DISK}p2"
        fi
        if [[ ! -b "$LUKS_PART" ]]; then
            log_error "Could not find LUKS partition on ${DISK}2"
        fi

        LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART" 2>/dev/null || true)
        if [[ -z "$LUKS_UUID" ]]; then
            log_error "Could not read UUID from LUKS partition $LUKS_PART"
        fi
        log_info "LUKS partition: $LUKS_PART (UUID=$LUKS_UUID)"

        # Verify /dev/mapper/cryptroot exists
        if [[ ! -b /dev/mapper/cryptroot ]]; then
            log_error "/dev/mapper/cryptroot not found — open the LUKS container first"
        fi
        log_info "Encrypted root: /dev/mapper/cryptroot"

        # Get UUID of the boot partition (for fstab)
        BOOT_UUID=$(blkid -s UUID -o value "$PART" 2>/dev/null || true)
        log_info "Boot partition: $PART (UUID=$BOOT_UUID)"
    else
        # Single partition — get its UUID for fstab
        UUID=$(blkid -s UUID -o value "$PART" 2>/dev/null || true)
        if [[ -z "$UUID" ]]; then
            log_error "Could not read UUID from $PART"
        fi
        log_info "Root partition: $PART (UUID=$UUID)"
    fi
}

# ──────────────────────────────────────────────
# Step 1: apt sources
# ──────────────────────────────────────────────
setup_apt_sources() {
    heading "Step 1: Configure apt sources"

    log_info "Writing /etc/apt/sources.list..."
    cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu/ resolute main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-updates main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu/ resolute-security main universe restricted multiverse
EOF
    log_ok "apt sources configured for Ubuntu 26.04 (Resolute Raccoon)"
}

# ──────────────────────────────────────────────
# Step 1b: DNS (needed before apt can resolve hostnames)
# ──────────────────────────────────────────────
setup_dns() {
    heading "Step 1b: Configure DNS for chroot"

    # The base tarball ships an empty /etc/resolv.conf. Inside a chroot,
    # systemd-resolved isn't running, so we write a static resolv.conf
    # for the package download phase. After reboot, systemd-resolved
    # will manage this file automatically.
    if [[ ! -s /etc/resolv.conf ]]; then
        cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
        log_ok "Written static resolv.conf (Cloudflare + Google DNS)"
    fi

    # Quick connectivity test
    if ! ping -c 1 -W 3 archive.ubuntu.com &>/dev/null; then
        log_warn "Cannot reach archive.ubuntu.com — check your internet connection"
    else
        log_ok "Network reachable"
    fi
}

# ──────────────────────────────────────────────
# Step 2: Install packages
# ──────────────────────────────────────────────
install_packages() {
    heading "Step 2: Install kernel, GRUB, and essential packages"

    log_info "Updating package lists..."
    apt-get update

    # Pre-seed debconf values to avoid interactive prompts inside chroot
    echo 'keyboard-configuration keyboard-configuration/layoutcode select us' | debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/xkb-keymap select us' | debconf-set-selections
    echo 'console-setup console-setup/codeset47 select UTF-8' | debconf-set-selections
    echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections
    echo 'tzdata tzdata/Zones/Europe select Berlin' | debconf-set-selections

    log_info "Installing base packages..."
    local extra_pkgs=""
    if $ENCRYPT; then
        extra_pkgs="cryptsetup-initramfs cryptsetup"
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    linux-generic \
    grub-pc \
    systemd \
    systemd-sysv \
    systemd-resolved \
    systemd-timesyncd \
    udev \
    dbus \
    openssh-server \
    sudo \
    nano \
    curl \
    ca-certificates \
    locales \
    keyboard-configuration \
    console-setup \
    $extra_pkgs

    log_ok "Base packages installed"
}

# ──────────────────────────────────────────────
# Step 3: (was Step 1b) Users and passwords
# ──────────────────────────────────────────────
set_password() {
    local user="$1"
    local pass="$2"
    local hash
    hash=$(openssl passwd -6 "$pass")
    # Write hash directly to /etc/shadow — chpasswd uses PAM which
    # fails inside chroot (dbus/systemd not running)
    sed -i "s|^$user:[^:]*:|$user:$hash:|" /etc/shadow
}

# ──────────────────────────────────────────────
# Step 3: (was Step 1b) Users and passwords
# ──────────────────────────────────────────────
setup_users() {
    heading "Step 3: Set up users"

    local root_pass=""
    local user_pass=""

    if [[ -n "$PASSWORD" ]]; then
        # Non-interactive: use the supplied password for both
        root_pass="$PASSWORD"
        user_pass="$PASSWORD"
        log_info "Using supplied password for root and $USERNAME"
    else
        # Interactive: prompt separately for each
        root_pass=$(prompt_password "root")
        user_pass=$(prompt_password "$USERNAME")
    fi

    set_password "root" "$root_pass"
    log_ok "Root password set"

    # Create user if not already exists
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -G sudo -s /bin/bash "$USERNAME"
    fi
    set_password "$USERNAME" "$user_pass"
    log_ok "User '$USERNAME' created with sudo access"
}

# ──────────────────────────────────────────────
# Step 4: Hostname and network identity (for after reboot)
# ──────────────────────────────────────────────
setup_network_identity() {
    heading "Step 4: Configure hostname and post-reboot networking"

    echo "$HOSTNAME" > /etc/hostname

    cat > /etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    log_ok "Hostname set to: $HOSTNAME"

    # Enable systemd-networkd for DHCP on next boot
    cat > /etc/systemd/network/20-wired.network << 'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    systemctl enable systemd-networkd 2>/dev/null || true
    systemctl enable systemd-resolved 2>/dev/null || true
    log_ok "Post-reboot networking configured (DHCP via systemd-networkd)"
}

# ──────────────────────────────────────────────
# Step 5: Locale and timezone
# ──────────────────────────────────────────────
setup_locale_timezone() {
    heading "Step 5: Configure locale and timezone"

    # Generate locale
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
    locale-gen
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8
    log_ok "Locale set to en_US.UTF-8"

    # Timezone detection or override
    if [[ -z "$TIMEZONE" ]]; then
    # Try to detect from current system's /etc/localtime symlink
    if [[ -L /etc/localtime ]]; then
        TIMEZONE=$(readlink -f /etc/localtime | sed 's|^.*/usr/share/zoneinfo/||')
    fi
    # Fallback
    if [[ -z "$TIMEZONE" ]]; then
        TIMEZONE="UTC"
    fi
    fi

    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    log_ok "Timezone set to: $TIMEZONE"

    # Enable time sync
    systemctl enable systemd-timesyncd 2>/dev/null || true
}

# ──────────────────────────────────────────────
# Step 6a: crypttab (only for encrypted install)
# ──────────────────────────────────────────────
setup_crypttab() {
    if ! $ENCRYPT; then
        return
    fi
    heading "Step 6a: Create /etc/crypttab"

    cat > /etc/crypttab << EOF
# 'initramfs' option forces inclusion of this entry in the initrd even when
# update-initramfs runs from a chroot (where get_mnt_devno sees the host's root
# and would otherwise leave the initrd crypttab empty -> boot can't unlock root).
cryptroot UUID=$LUKS_UUID none luks,initramfs
EOF
    log_ok "crypttab created (cryptroot ← UUID=$LUKS_UUID, initramfs flag)"

    # Ensure realpath ships in the initrd: scripts/local-bottom/cryptroot calls
    # it after the root mounts, and busybox has no realpath applet.
    mkdir -p /etc/initramfs-tools/hooks
    cat > /etc/initramfs-tools/hooks/realpath << 'HOOK'
#!/bin/sh
# Ensure realpath is in the initrd (scripts/local-bottom/cryptroot needs it).
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0 ;;
esac
. /usr/share/initramfs-tools/hook-functions
copy_exec /usr/bin/realpath /usr/bin/realpath
HOOK
    chmod +x /etc/initramfs-tools/hooks/realpath
    log_ok "realpath initramfs hook installed"
}

# ──────────────────────────────────────────────
# Step 6b: fstab
# ──────────────────────────────────────────────
setup_fstab() {
    heading "Step 6b: Create /etc/fstab"

    if $ENCRYPT; then
        cat > /etc/fstab << EOF
/dev/mapper/cryptroot / ext4 noatime,errors=remount-ro 0 1
UUID=$BOOT_UUID /boot ext4 noatime 0 2
EOF
        log_ok "fstab created (/dev/mapper/cryptroot → /, UUID=$BOOT_UUID → /boot, noatime)"
    else
        cat > /etc/fstab << EOF
UUID=$UUID / ext4 noatime,errors=remount-ro 0 1
EOF
        log_ok "fstab created (UUID=$UUID → /, noatime)"
    fi
}

# ──────────────────────────────────────────────
# Step 7: GRUB
# ──────────────────────────────────────────────
install_grub() {
    heading "Step 7: Install GRUB bootloader"

    if $ENCRYPT; then
        log_info "Configuring GRUB for LUKS..."
        # Enable cryptodisk support in GRUB
        echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
        # Add cryptdevice kernel parameter
        if grep -q '^GRUB_CMDLINE_LINUX=""' /etc/default/grub; then
            sed -i 's|^GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="cryptdevice=UUID='"$LUKS_UUID"':cryptroot"|' /etc/default/grub
        else
            # Append to existing
            sed -i "s|^GRUB_CMDLINE_LINUX=\"|\0cryptdevice=UUID=$LUKS_UUID:cryptroot |" /etc/default/grub
        fi
        log_ok "GRUB configured for LUKS (cryptdevice=UUID=$LUKS_UUID:cryptroot)"
    fi

    log_info "Installing GRUB to $DISK..."
    grub-install "$DISK"
    update-grub
    # Rebuild the initrd now that /etc/crypttab (initramfs flag) and the
    # realpath hook exist: the kernel package postinst builds it too early
    # (before crypttab is written), which leaves it without LUKS support.
    update-initramfs -u -k all
    log_ok "GRUB installed to $DISK"
}

# ──────────────────────────────────────────────
# Step 8: Cleanup
# ──────────────────────────────────────────────
cleanup() {
    heading "Step 8: Cleanup"

    apt-get autoremove --purge -y
    apt-get autoclean -y
    log_ok "Package cache cleaned"

    # Remove self from /root
    rm -f "/root/$(basename "$0")"
}

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
print_summary() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  Ubuntu Base Configuration — Complete"
    echo "══════════════════════════════════════════════"
    echo ""
    echo "  Target disk:     $DISK"
    echo "  Hostname:        $HOSTNAME"
    echo "  Username:        $USERNAME"
    echo "  Timezone:        $TIMEZONE"
    echo ""
    echo "  What was done:"
    echo "  ✓ apt sources configured"
    echo "  ✓ DNS configured (static resolv.conf for chroot)"
    echo "  ✓ Kernel + GRUB installed"
    echo "  ✓ Root password set"
    echo "  ✓ User '$USERNAME' created"
    echo "  ✓ Hostname + post-reboot networking configured"
    echo "  ✓ Locale (en_US.UTF-8) + timezone set"
    echo "  ✓ /etc/fstab created"
    echo "  ✓ GRUB installed to $DISK"
    echo ""
    echo "  Next steps:"
    echo "    1. Exit chroot:     exit"
    echo "    2. Unmount:         sudo umount -R /mnt"
    echo "    3. Reboot:          sudo reboot"
    echo "    4. After reboot, run:"
    echo "       sudo ~/fresh-install.sh"
    echo ""
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
main() {
    parse_args "$@"

    echo "══════════════════════════════════════════════"
    echo "  Ubuntu Base Chroot Configurator v$VERSION"
    echo "══════════════════════════════════════════════"
    echo ""

    validate

    setup_apt_sources
    setup_dns
    install_packages
    setup_users
    setup_network_identity
    setup_locale_timezone
    setup_crypttab
    setup_fstab
    install_grub
    cleanup

    print_summary
}

main "$@"
