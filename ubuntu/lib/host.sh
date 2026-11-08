#!/bin/sh
# Load this machine's values. Sourced, not executed:
#
#   repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
#   . "$repo/ubuntu/lib/host.sh"
#
# The filename is fixed on purpose: ubuntu/hosts/host.sh is the one place values
# live, on every machine. It is gitignored because this repo is public, and
# ubuntu/hosts/host.example.sh is the tracked contract to copy. Deriving the
# name from the hostname was clever at the cost of being obvious.
#
# Every address, domain and account name a script needs comes from that file, so
# no script in this repo carries one.

: "${repo:?ubuntu/lib/host.sh: set \$repo to the dotfiles checkout first}"

host_file="$repo/ubuntu/hosts/host.sh"

if [ ! -r "$host_file" ]; then
	echo "host: missing $host_file" >&2
	echo "host: cp ubuntu/hosts/host.example.sh ubuntu/hosts/host.sh and fill it in" >&2
	return 1
fi

# shellcheck source=/dev/null  # gitignored, machine-local
. "$host_file"

# True when a value is still a placeholder from the example file. The example
# uses documentation ranges (RFC 5737) and example.* names, so this cannot fire
# on a real configuration by accident.
host_placeholder() {
	case ${1-} in
		'' | *example* | *Example* | 192.0.2.* | 198.51.100.* | 203.0.113.*) return 0 ;;
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
	echo "host values: $host_file"
}
