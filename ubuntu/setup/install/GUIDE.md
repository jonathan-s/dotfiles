# Ubuntu 26.04 — Minimal Install Guide

## Quick Start (Fresh SSD Install)

If you're installing on a **fresh SSD** from the Ubuntu Server ISO, this is the fastest path:

```bash
# 1. Install Ubuntu Server ISO
# 2. Get this checkout and run the script:
sudo apt update && sudo apt install -y git
git clone https://github.com/jonathan-s/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles/ubuntu/setup/install
sudo ./fresh-install.sh
# 3. Reboot
sudo reboot
```

The `fresh-install.sh` script does everything in one pass:
- Installs `ubuntu-desktop-minimal` (GNOME core, no bloat)
- Removes snapd, LibreOffice, games, and other bloat
- Tunes systemd services, kernel parameters, ZRAM
- Enables SSD TRIM, noatime mount, fast GRUB
- Sets up Flatpak + Flathub

---

## All Approaches

This guide covers **7 approaches** for getting a clean, performant Ubuntu desktop.
See the selection guide at the bottom to pick the right one for your needs.

---

## Approach A: Fresh Install from Ubuntu Server ISO (Cleanest)

Start with zero bloat by using the Ubuntu Server ISO and adding only what you need.
This is the manual version of what `fresh-install.sh` automates.

### Step 1: Download Ubuntu Server ISO
Grab the latest Ubuntu 26.04 LTS Server image:
https://ubuntu.com/download/server

### Step 2: Create bootable USB
```bash
# Find your USB device
lsblk
# Write ISO to USB (replace /dev/sdX with your device)
sudo dd if=ubuntu-26.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
```

### Step 3: Install base system
Boot from USB, go through the installation wizard. Do **not** select any snap packages.
Select "OpenSSH server" only if you need remote access.

### Step 4: Install minimal desktop
After first boot and login:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install a minimal desktop environment
# Option 1: GNOME (stock Ubuntu DE)
sudo apt install --no-install-recommends ubuntu-desktop-minimal

# Option 2: XFCE (lighter than GNOME)
sudo apt install --no-install-recommends xubuntu-desktop

# Option 3: Build your own (lightest)
sudo apt install --no-install-recommends \
    xorg lightdm lightdm-gtk-greeter \
    gnome-session gnome-panel gnome-terminal \
    nautilus firefox
```

### Step 5: Remove snapd (optional but recommended)
```bash
sudo snap remove --purge snapd
sudo apt purge -y snapd
sudo apt-mark hold snapd
```

### Step 6: Install your preferred apps
```bash
sudo apt install --no-install-recommends \
    build-essential git curl wget \
    firefox thunderbird \
    gnome-tweaks synaptic
```

---

## Approach B: Debloat Existing Ubuntu Install (Fastest)

Run the included script on a standard Ubuntu 26.04 desktop installation.

### Quick Start
```bash
sudo ./ubuntu-debloat.sh
```

### Dry Run (Preview Only)
```bash
sudo ./ubuntu-debloat.sh --dry-run
```

### What the Script Does

| Step | Action |
|------|--------|
| 1. Remove Snap | Removes all snap packages and snapd; pins it from return |
| 2. Remove APT Bloat | LibreOffice, games, media players, GNOME extras, Remmina, etc. |
| 3. Install Tools | Build tools, Python, Clang toolchain, USB/serial tools, GNOME Tweaks, Synaptic |
| 4. Install Browser | Brave browser (privacy-focused, Chromium-based) |
| 5. Configure GNOME | Disable middle-click paste, show hidden files, dark theme, no auto-suspend |
| 6. Final Cleanup | Autoremove orphans, purge residual configs, clean cache, trim logs |

### Post-Install Recommendations
```bash
# Reboot to apply all changes
sudo reboot

# Install VS Code (if desired)
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install code
```

---

## Additional Optimizations

### Reduce Memory Usage
```bash
# Reduce swappiness (use RAM, not swap, for caching)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Disable unnecessary services
sudo systemctl disable --now bluetooth.service  # if you don't use Bluetooth
sudo systemctl disable --now cups.service       # if you don't print
sudo systemctl disable --now avahi-daemon       # if you don't need .local mDNS
```

### Install Flatpak (Snap Alternative)
```bash
sudo apt install flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
# Install GNOME Software plugin for Flatpak
sudo apt install gnome-software-plugin-flatpak
```

### Clean Up Fonts
```bash
# Remove unnecessary font packages
sudo apt purge fonts-tibetan-chinese fonts-khmeros fonts-lao fonts-gujr \
    fonts-guru fonts-orya fonts-telu fonts-mlym fonts-knda fonts-beng
```

---

## Approach C: Post-Install System Tuning (Leanest Runtime)

Even after removing bloat packages, the running system may still consume more
resources than necessary. The `system-tune.sh` script handles runtime optimization:

- **Disables unnecessary systemd services** — Bluetooth, printing, mDNS, ModemManager, whoopsie (error reporting)
- **Configure kernel parameters** — swappiness=10, disable watchdog timers, reduce dirty page writeback
- **Enables ZRAM** — compresses swap in RAM (equivalent to adding ~50-100% more usable memory)
- **Optionally disables mitigations** — `mitigations=off nowatchdog` boot params (security trade-off for performance)
- **Optimizes I/O scheduler** — uses `mq-deadline` or `none` for SSDs

```bash
sudo ./system-tune.sh
```

---

## Approach D: Ubuntu Base + debootstrap (Ultra Minimal)

Start from a bare rootfs (33MB tarball) and build up only what you need.
No installer, no bloat, maximum control.

### One-command install (recommended)

The `ubuntu-base-install.sh` script handles the full workflow: LUKS setup,
formatting, base extraction, chroot configuration, package installation,
and GRUB.

#### Partition first

Create the partition layout before running the script:

```bash
# Plain install (single partition):
sudo fdisk /dev/sdX    # create one partition (sdX1 = /)

# Encrypted install (two partitions):
sudo fdisk /dev/sdX    # create two partitions:
                       #   sdX1 = ~1G (ext4 /boot)
                       #   sdX2 = rest (LUKS /)
```

#### Run

```bash
# Plain install (prompts for passwords):
sudo ./ubuntu-base-install.sh /dev/sdX

# Encrypted install with supplied password:
sudo ./ubuntu-base-install.sh /dev/sdX --encrypt --password "mypass"

# Full options:
sudo ./ubuntu-base-install.sh /dev/sdX --encrypt \
    --hostname mybox --user me \
    --timezone Europe/Berlin --password "mypass"
```

The script handles:
1. **LUKS** — creates and opens the encrypted container
2. **Format** — formats boot (ext4) and root (ext4 on LUKS)
3. **Mount** — mounts boot and root at correct locations
4. **Download** — fetches the 33MB ubuntu-base tarball (reuses cached copy)
5. **Extract** — unpacks base system
6. **Chroot** — configures everything inside the chroot:
   - apt sources, DNS, kernel, GRUB
   - cryptsetup (if encrypted), crypttab
   - fstab with noatime (handles LUKS + boot partitions)
   - GRUB with `GRUB_ENABLE_CRYPTODISK=y` and `cryptdevice=` (if encrypted)
   - users, hostname, networking, locale, timezone

#### Clean up

```bash
sudo umount -R /mnt
sudo reboot
```

#### Post-install

Once booted, run the bootstrap to install the desktop:

```bash
sudo ~/fresh-install.sh
```

Desktop decision for this machine (recorded 2026-09 with the elementaryOS ->
Ubuntu resolute migration): **GNOME via `ubuntu-desktop-minimal` with gdm3**
(Wayland session), replacing the old elementary Pantheon/lightdm stack. i3
remains installed as an X session alternative (see `packages.sh`).

### Manual (two-script approach)

If you prefer to run the prep and chroot steps separately:

```bash
# 1. Partition and format
sudo fdisk /dev/sdX
sudo mkfs.ext4 /dev/sdX1
sudo mount /dev/sdX1 /mnt

# 2. Download and extract (or use --encrypt for LUKS)
sudo ./ubuntu-base-install.sh /dev/sdX --encrypt --password "pass" --skip-chroot

# 3. Or do it by hand:
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt /root/ubuntu-base-chroot.sh /dev/sdX --encrypt --password "pass"

# 4. Cleanup
sudo umount -R /mnt
sudo reboot
```

### Footprint

**Expected footprint**: ~2-3 GB disk, ~400-600 MB RAM

---

## Approach E: ubuntu-desktop-minimal (Official Minimal Desktop)

Canonical ships an official minimal desktop metapackage. This is the quickest
path to a clean Ubuntu without going full manual.

### During installer (easiest)
When installing Ubuntu 26.04 desktop ISO, choose:
- **"Minimal installation"** — skips LibreOffice, Thunderbird, games, most snaps

### From server ISO
If you already installed from server ISO:
```bash
sudo apt install --no-install-recommends ubuntu-desktop-minimal
```

This pulls in GNOME core (Shell, Mutter, Settings, Files, Terminal) but *not*:
- LibreOffice, Thunderbird, Firefox snap
- Games, Rhythmbox, Shotwell, Transmission
- Most GNOME Circle apps

**Still included** (can be removed after):
- GNOME Calendar, Maps, Weather, Contacts
- Evolution data server (backend for calendar/contacts)

```bash
# Optional post-install removal
sudo apt purge gnome-calendar gnome-maps gnome-weather gnome-contacts evolution-data-server
```

**Expected footprint**: ~3-4 GB disk, ~600-800 MB RAM

---

## Approach F: Cubic Custom ISO (Reproducible)

For a *reproducible, shareable* Ubuntu install, remaster the ISO with your
exact package set using [Cubic](https://github.com/PJ-Singh-001/Cubic).

### Steps
1. Install Cubic on an Ubuntu machine:
   ```bash
   sudo add-apt-repository ppa:cubic-wizard/release
   sudo apt update && sudo apt install cubic
   ```
2. Launch Cubic, point it at the Ubuntu 26.04 ISO
3. In the chroot terminal:
   - Remove snapd, bloat packages
   - Install desired tools
   - Run `system-tune.sh`
   - Configure preseed for automated installation
4. Generate new ISO
5. Boot from custom ISO — your exact system, every time

**Best for**: Deployment across multiple machines, sharing with others, or
creating a personal "golden image".

---

## Approach G: Autoinstall / Preseed (Automated)

Use Ubuntu's cloud-init/curtin for fully automated bare-metal installs.
Primarily designed for server, but works for desktops too.

### Minimal example (user-data file):
```yaml
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: minimal-ubuntu
    username: youruser
    password: "$6$..."  # mkpasswd --method=sha-512
  packages:
    - ubuntu-desktop-minimal
    - build-essential
    - git
    - gnome-tweaks
  snaps: []                   # No snaps
  late-commands:
    - apt purge snapd -y
    - apt-mark hold snapd
```

### Usage
1. Place `user-data` and `meta-data` on a USB drive labeled `CIDATA`
2. Boot from Ubuntu server ISO
3. The installer will automatically apply your config — zero interaction

---

## Approach Selection Guide

| If you want... | Use approach... |
|---|---|
| **Fresh SSD install (recommended)** | **A: `fresh-install.sh`** — one command from server ISO |
| Debloat existing install, no reinstall | B: `ubuntu-debloat.sh` |
| Leanest RAM usage | C: `system-tune.sh` + any other |
| Absolute smallest footprint | **D: Ubuntu Base + debootstrap** — with optional LUKS |
| Fast minimal desktop from server ISO | E: `ubuntu-desktop-minimal` (manual) |
| Reproducible custom ISO | F: Cubic |
| Automated deployment | G: Autoinstall/preseed |

---

## Disk Space & RAM Comparison

| Approach | Disk Usage | RAM (idle) | Effort |
|----------|-----------|------------|--------|
| Stock Ubuntu 26.04 Desktop | ~8-10 GB | ~1.2-1.5 GB | None |
| **fresh-install.sh** (Approach A) | **~3-4 GB** | **~500-700 MB** | **Low** |
| debloat only (Approach B) | ~4-5 GB | ~700-900 MB | Low |
| + system-tune.sh (Approach C) | ~4-5 GB | ~500-700 MB | Low |
| ubuntu-desktop-minimal (Approach E) | ~3-4 GB | ~600-800 MB | Medium |
| Ubuntu Base + DE (Approach D) | ~2-3 GB | ~400-600 MB | **Low** (with `ubuntu-base-install.sh`) |

---

## Reference

This guide was compiled from research across multiple sources in June 2026.
See `00-RESEARCH-LOG.md` for detailed analysis of each source.
