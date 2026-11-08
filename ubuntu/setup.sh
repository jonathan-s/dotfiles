#!/bin/sh
# ubuntu/setup.sh — the Linux half of the platform stage.
#
#   ./ubuntu/setup.sh             apply what can be applied without sudo
#   ./ubuntu/setup.sh --check     report drift, change nothing
#   ./ubuntu/setup.sh --quiet     apply, no chatter
#   ./ubuntu/setup.sh --list      what this manages
#
# Unlike macos/defaults.sh this has no module directory yet: there is no
# gsettings module and no dconf dump worth tracking, so it manages the two
# things that are actually true today — the host-values file is complete, and
# the daily history expiry is installed.
#
# Anything needing root lives in ubuntu/setup/ (bootstrap.sh) and is never
# applied implicitly.

set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

mode=apply
for arg in "$@"; do
	case $arg in
		--check) mode=check ;;
		--quiet) mode=quiet ;;
		--list)
			cat <<'EOF'
host-values   ubuntu/hosts/<hostname>.sh has no placeholders left
crontab       @daily bin/expire-history.sh for the login user
EOF
			exit 0
			;;
		-h | --help)
			sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "ubuntu/setup.sh: unknown option: $arg" >&2
			exit 2
			;;
	esac
done

# shellcheck source=/dev/null  # gitignored, machine-local
. "$repo/ubuntu/lib/host.sh"

home_dir=$(getent passwd "$LOGIN_USER" | cut -d: -f6)
home_dir=${home_dir:-$HOME}
cron_line="@daily /bin/bash $home_dir/bin/expire-history.sh"

say() {
	[ "$mode" = quiet ] || echo "$@"
}

drift=0
problem() {
	drift=1
}

# ─── host values ─────────────────────────────────────────────────────────────
if ! host_check > /dev/null 2>&1; then
	host_check || true
	problem
elif [ "$mode" != quiet ]; then
	say "host values: complete"
fi

# ─── daily history expiry ────────────────────────────────────────────────────
crontab_read() {
	# -u needs root; the login user's own crontab does not.
	if [ "$(id -un)" = "$LOGIN_USER" ]; then
		crontab -l 2> /dev/null || true
	else
		sudo -u "$LOGIN_USER" crontab -l 2> /dev/null || true
	fi
}

crontab_write() {
	if [ "$(id -un)" = "$LOGIN_USER" ]; then
		crontab -
	else
		sudo -u "$LOGIN_USER" crontab -
	fi
}

current=$(crontab_read)
if printf '%s\n' "$current" | grep -qF 'bin/expire-history.sh'; then
	[ "$mode" = quiet ] || say "crontab: history expiry installed"
elif [ "$mode" = check ]; then
	echo "drift: crontab has no bin/expire-history.sh entry" >&2
	problem
else
	{
		printf '%s\n' "$current"
		printf '%s\n' "$cron_line"
	} | sed '/^[[:space:]]*$/d' | crontab_write
	say "crontab: history expiry installed"
fi

if [ "$mode" = check ]; then
	if [ "$drift" -eq 0 ]; then
		echo "ubuntu setup: no drift"
		exit 0
	fi
	echo "ubuntu setup: drift" >&2
	exit 1
fi
