#!/usr/bin/env bash
# packages.sh — the apt half of this machine's package list.
#
# The rule: apt owns what is server-exclusive, security-related or system-level
# — daemons, systemd units, anything needing root or /etc, the login shell, the
# desktop session. Everything that is toolchain lives in brew/Brewfile and is
# installed by ./install, so the two lists cannot drift into each other.
#
#   sudo bash ubuntu/apt/packages.sh
#
# Idempotent: every line is a plain `apt install`, so a re-run is a no-op. It is
# a manifest, not a log — installing something by hand means adding a line here
# in the same commit, not appending to a history.
#
# Docker needs its own apt repository before this runs:
#   https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

set -euo pipefail

# ─── Prerequisites ───────────────────────────────────────────────────────────
# ca-certificates and curl are needed before Homebrew can be installed, so they
# come first and are the only reason this script has an order.
sudo apt install -y ca-certificates curl

# console-setup provides setupcon, used to apply the keyboard layout at boot.
sudo apt install -y console-setup

# ─── Repositories ────────────────────────────────────────────────────────────
sudo apt install -y extrepo
sudo apt install -y software-properties-common

# ─── System services ─────────────────────────────────────────────────────────
# Daemons and anything that binds a privileged port or installs a systemd unit.
sudo apt install -y openssh-server
sudo apt install -y dnsmasq
sudo apt install -y dnsutils
sudo apt install -y input-remapper
sudo apt install -y podman
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ─── Shell and Python ────────────────────────────────────────────────────────
# zsh must exist in /etc/shells before it can be anyone's login shell, which is
# why it is apt and not Homebrew. Python itself is pyenv's job (see ./install),
# but pyenv needs these headers to build an interpreter.
sudo apt install -y zsh
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
	libreadline-dev libsqlite3-dev liblzma-dev libffi-dev libncursesw5-dev \
	tk-dev xz-utils
# Invoke runs the homelab tasks.py; it stays with the distro interpreter that
# paperless uses. pip does not: uv is the Python frontend on both machines.
sudo apt install -y python3-invoke

# ─── Desktop ─────────────────────────────────────────────────────────────────
# No Homebrew formula exists for any of these, and each one needs a desktop
# file, GSettings schemas or an X session to be useful.
sudo apt install -y i3
sudo apt install -y tilix
sudo apt install -y ulauncher

# Ghostty is not in any apt repository; the installer builds a .deb. It is
# guarded because that installer fetches the latest release every time, and an
# idempotent manifest must not upgrade the terminal emulator on every run.
if ! command -v ghostty > /dev/null 2>&1; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
fi
