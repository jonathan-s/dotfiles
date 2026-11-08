#!/usr/bin/env bash
# bootstrap.sh — bring a freshly installed Ubuntu box up to this repository.
#
#   sudo bash ubuntu/setup/bootstrap.sh
#
#   1. apt packages      ubuntu/apt/packages.sh
#   2. dotfiles + brew   ../install (packages, tools, links, platform, shell)
#   3. machine identity  hostname, timezone, from ubuntu/hosts/<host>.sh
#   4. sshd               key-only auth, no root login
#   5. keyboard           Swedish Dvorak, TTY and desktop
#
# Deliberately not included:
#   - the router's wildcard DNS — run ubuntu/setup/router-dns.sh on the router
#   - docker's DNS             — run ubuntu/setup/docker-dns.sh after docker
#   - dokku, apps and the operating history — those live in the homelab repo
#
# Idempotent: safe to re-run.

set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=/dev/null  # gitignored, machine-local
. "$repo/ubuntu/lib/host.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

[ "$(id -u)" = 0 ] || {
	echo "bootstrap: run this as root" >&2
	exit 1
}

# ─── 1. Packages ─────────────────────────────────────────────────────────────
section "1. apt packages"
info "Running ubuntu/apt/packages.sh..."
bash "$repo/ubuntu/apt/packages.sh"
ok "apt packages installed."

# ─── 2. Dotfiles and Homebrew toolchain ──────────────────────────────────────
section "2. dotfiles"
# install expects to run as the login user, not root: it links into $HOME and
# changes the login shell. Re-exec it through sudo -u.
LOGIN_UID=$(id -u "$LOGIN_USER")
if [ "$LOGIN_UID" = 0 ]; then
	warn "LOGIN_USER=$LOGIN_USER is root; skipping the dotfiles stage."
else
	info "Running ./install as $LOGIN_USER..."
	sudo -u "$LOGIN_USER" env HOME="$(getent passwd "$LOGIN_USER" | cut -d: -f6)" \
		bash -lc "cd '$repo' && ./install" || warn "install reported drift; re-run it as $LOGIN_USER to see why."
fi

# ─── 3. Machine identity ─────────────────────────────────────────────────────
section "3. hostname and timezone"

CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" = "$HOST_NAME" ]; then
	ok "hostname already $HOST_NAME."
else
	info "Setting hostname to $HOST_NAME..."
	hostnamectl set-hostname "$HOST_NAME"
	ok "hostname set."
fi

# Ubuntu resolves the hostname through nss-myhostname, but some services (the
# dokku installer among them) do a direct /etc/hosts lookup and fail without an
# explicit entry. Avahi covers .local, this covers local self-lookups.
if grep -qE "^127\.0\.0\.1[[:space:]].*\b${HOST_NAME}\b" /etc/hosts; then
	ok "$HOST_NAME already in /etc/hosts."
else
	info "Adding $HOST_NAME to /etc/hosts..."
	sed -i "s/^127\.0\.0\.1[[:space:]]*localhost/127.0.0.1\tlocalhost\t${HOST_NAME}/" /etc/hosts
	ok "$HOST_NAME added to /etc/hosts."
fi

if [ -n "${TIMEZONE:-}" ]; then
	timedatectl set-timezone "$TIMEZONE"
	ok "timezone set to $TIMEZONE."
fi

# ─── 4. SSH ──────────────────────────────────────────────────────────────────
section "4. sshd"

SSHD_CONFIG=/etc/ssh/sshd_config

set_sshd_option() { # key value
	if grep -qE "^#?${1}" "$SSHD_CONFIG"; then
		sed -i "s/^#*${1}.*/${1} ${2}/" "$SSHD_CONFIG"
	else
		echo "${1} ${2}" >> "$SSHD_CONFIG"
	fi
}

info "Hardening $SSHD_CONFIG..."
set_sshd_option PasswordAuthentication no
set_sshd_option PermitRootLogin no
ok "sshd_config updated."

AUTHORIZED_KEYS="/home/$LOGIN_USER/.ssh/authorized_keys"
if sudo -u "$LOGIN_USER" test -s "$AUTHORIZED_KEYS"; then
	ok "authorized_keys already populated."
else
	warn "No $AUTHORIZED_KEYS. Add a key before relying on key-only auth:"
	warn "  ssh-copy-id $LOGIN_USER@$HOST_NAME.local"
fi

systemctl enable ssh > /dev/null 2>&1
systemctl restart ssh
ok "ssh enabled and restarted."

# ─── 5. Keyboard ─────────────────────────────────────────────────────────────
section "5. keyboard layout"

# /etc/default/keyboard is read by console-setup for both the TTY and the
# desktop session, so this one file covers both.
info "Setting the keyboard layout to se(dvorak)..."
cat > /etc/default/keyboard <<'EOF'
XKBLAYOUT=se
BACKSPACE=guess
XKBVARIANT=dvorak
EOF
setupcon > /dev/null 2>&1 || warn "setupcon failed; the TTY layout will apply on next boot."
ok "keyboard layout set."

# ─── Done ────────────────────────────────────────────────────────────────────
section "done"
echo
info "Next steps:"
echo "  - router wildcard DNS:  on the router, with LAN_* from ubuntu/hosts/host.sh"
echo "  - docker DNS:           sudo bash $repo/ubuntu/setup/docker-dns.sh"
echo "  - dokku and the apps:   homelab/setup/setup-dokku.sh"
echo "  - verify the machine:   $repo/bootstrap --report"
