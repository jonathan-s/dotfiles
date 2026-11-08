#!/bin/sh
# Load this machine's values. Sourced, not executed:
#
#   repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
#   . "$repo/ubuntu/lib/host.sh"
#
# Every address, domain and account name a script needs comes from here, so no
# script in this repo carries one. The real file is gitignored because this repo
# is public; ubuntu/hosts/host.example.sh documents the contract and
# is the file to copy on a new machine.

: "${repo:?ubuntu/lib/host.sh: set \$repo to the dotfiles checkout first}"

host_name=${DOTFILES_HOST:-$(hostname -s 2>/dev/null || hostname)}
host_file="$repo/ubuntu/hosts/$host_name.sh"

if [ ! -r "$host_file" ]; then
	echo "host: missing $host_file" >&2
	echo "host: copy the tracked example in ubuntu/hosts/ to that name and fill it in" >&2
	# Sourced by our scripts, so this returns; running the file directly is the
	# only way to reach the exit, and it is a mistake worth failing on.
	return 1
fi

# shellcheck source=/dev/null  # the real file is gitignored and machine-local
. "$host_file"

# True when a value is still the placeholder from the example file. The example
# uses documentation ranges (RFC 5737, example.com), so this cannot fire on a
# real configuration by accident.
host_placeholder() {
	case ${1-} in
		'' | *example* | 192.0.2.* | 198.51.100.* | 203.0.113.*) return 0 ;;
	esac
	return 1
}

# Report every value that is still a placeholder. Used by ./install --check.
host_check() {
	missing=
	for var in HOST_NAME LOGIN_USER TIMEZONE LAN_SUBNET LAN_ROUTER_IP LAN_SERVER_IP LAN_DOMAIN PUBLIC_DOMAIN ACME_EMAIL; do
		value=
		eval "value=\${$var-}"
		host_placeholder "$value" && missing="$missing $var"
	done
	if [ -n "$missing" ]; then
		echo "placeholder in $host_file:$missing" >&2
		return 1
	fi
	echo "host values: $host_name"
}
