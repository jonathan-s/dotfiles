#!/bin/sh
# router-dns.sh — wildcard LAN DNS on an OpenWrt router.
#
# Runs ON THE ROUTER, as root, not on the server: it edits the router's UCI
# config, which is where dnsmasq lives once you want every device on the LAN to
# resolve *.your-domain to the server.
#
# The addresses and domains are supplied by the caller, because this file is in
# a public repository. On the server they come from ubuntu/hosts/<host>.sh,
# which is gitignored:
#
#   LAN_ROUTER_IP=... LAN_SERVER_IP=... LAN_DOMAIN=... PUBLIC_DOMAIN=... \
#       sh router-dns.sh
#
# Idempotent: safe to re-run, and it leaves unrelated router settings alone.
# Verified against GL.iNet 4.11 (GL-MT6000): wildcards are added as `address`
# entries only, and a dnsmasq that fails to come back up is rolled back.

set -eu

: "${LAN_ROUTER_IP:?set LAN_ROUTER_IP to the router address}"
: "${LAN_SERVER_IP:?set LAN_SERVER_IP to the server address}"
: "${LAN_DOMAIN:?set LAN_DOMAIN to the LAN domain, e.g. home.example.lan}"
: "${PUBLIC_DOMAIN:?set PUBLIC_DOMAIN to the dokku domain}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { printf '%b[INFO]%b  %s\n' "$CYAN" "$NC" "$*"; }
ok()   { printf '%b[OK]%b    %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b[WARN]%b  %s\n' "$YELLOW" "$NC" "$*"; }

# The dnsmasq search domain is the last label of the LAN domain.
DOMAIN_SUFFIX=${LAN_DOMAIN#*.}

# ─── 0. Preconditions ────────────────────────────────────────────────────────
command -v uci > /dev/null 2>&1 || {
	echo "uci not found — this script targets OpenWrt routers." >&2
	exit 1
}
[ "$(id -u)" = 0 ] || {
	echo "Must run as root on the router." >&2
	exit 1
}

# list_has checks whether a UCI list already contains a value. It reads the
# option directly instead of grepping `uci show`, so the comparison is exact and
# can never match a different section's option.
list_has() { # section option value
	uci -q get "${1}.${2}" 2> /dev/null | tr ' ' '\n' | grep -qxF "$3"
}
add_list() { # section option value
	if list_has "$1" "$2" "$3"; then
		echo "  already present: $2: $3"
	else
		uci add_list "${1}.${2}=${3}" > /dev/null
		echo "        adding:      $2: $3"
	fi
}

# ─── 1. dnsmasq local search domain ──────────────────────────────────────────
info "Setting the dnsmasq search domain to '$DOMAIN_SUFFIX'..."
uci set "dhcp.@dnsmasq[0].domain=$DOMAIN_SUFFIX"
ok "dnsmasq domain set to '$DOMAIN_SUFFIX'."

# ─── 2. Wildcard DNS for the LAN and public domains ─────────────────────────
# `address=/domain/ip` already answers every name in the domain locally, so
# `local=/domain/` entries add nothing — and on GL.iNet firmware they are
# actively harmful: the generator joins the whole `local` UCI list with spaces
# onto one line,
#
#     local=/lan/ /home.example.lan/ /home.example.com/
#
# which dnsmasq rejects ("error at line 15"), so it never starts and the entire
# LAN loses DNS. `address` entries are emitted one per line and are safe.
info "Ensuring *.$LAN_DOMAIN and *.$PUBLIC_DOMAIN resolve to $LAN_SERVER_IP..."
add_list 'dhcp.@dnsmasq[0]' address "/$LAN_DOMAIN/$LAN_SERVER_IP"
add_list 'dhcp.@dnsmasq[0]' address "/$PUBLIC_DOMAIN/$LAN_SERVER_IP"
ok "Wildcard entries ensured."

# ─── 3. Advertise the router as DNS to DHCP clients ─────────────────────────
info "Making LAN DHCP advertise $LAN_ROUTER_IP as DNS (option 6)..."
add_list 'dhcp.lan' dhcp_option "6,$LAN_ROUTER_IP"
ok "DHCP DNS advertisement ensured."

dnsmasq_running() { pgrep -f dnsmasq > /dev/null 2>&1; }

# A config dnsmasq cannot parse leaves DNS down for every client, so keep the
# pre-change file and undo the change when verification fails.
rollback() { # reason
	warn "$1"
	if [ -z "$DHCP_BACKUP" ] || [ ! -f "$DHCP_BACKUP" ]; then
		echo "No backup available — restore /etc/config/dhcp by hand." >&2
		exit 1
	fi
	info "Rolling back to the pre-change dhcp config..."
	cp "$DHCP_BACKUP" /etc/config/dhcp
	uci commit dhcp
	/etc/init.d/dnsmasq restart > /dev/null 2>&1
	sleep 2
	if dnsmasq_running; then
		ok "Rolled back; dnsmasq is running again."
	else
		warn "dnsmasq still down after rollback — check it by hand."
	fi
	exit 1
}

# ─── 4. Backup, commit and restart ───────────────────────────────────────────
DHCP_BACKUP=
if [ -f /etc/config/dhcp ]; then
	DHCP_BACKUP=/tmp/dhcp.pre-router-dns.$$
	cp /etc/config/dhcp "$DHCP_BACKUP"
fi

info "Committing UCI config and restarting dnsmasq..."
uci commit dhcp
/etc/init.d/dnsmasq restart > /dev/null 2>&1
sleep 2

if dnsmasq_running; then
	ok "dnsmasq restarted."
else
	logread 2> /dev/null | grep -i 'dnsmasq.*\(error\|FAILED\)' | tail -n3
	rollback "dnsmasq is not running after the restart."
fi

# ─── 5. Verify ───────────────────────────────────────────────────────────────
# Query the router's own address: GL.iNet's dnsmasq runs with bind-dynamic and
# local-service, so it does not answer on 127.0.0.1 even when it is healthy.
info "Verifying wildcard DNS via $LAN_ROUTER_IP..."
LOCAL=$(dig +short "test.$LAN_DOMAIN" "@$LAN_ROUTER_IP" 2> /dev/null | tail -n1)
if [ "$LOCAL" = "$LAN_SERVER_IP" ]; then
	ok "test.$LAN_DOMAIN → $LOCAL"
else
	rollback "Wildcard check failed: got '$LOCAL', expected $LAN_SERVER_IP."
fi

info "Verifying external DNS..."
EXTERNAL=$(dig +short example.com "@$LAN_ROUTER_IP" 2> /dev/null | tail -n1)
if [ -n "$EXTERNAL" ]; then
	ok "External DNS working (example.com → $EXTERNAL)"
else
	warn "External DNS not resolving — check upstream WAN DNS (unrelated to this change)."
fi

printf '\n%s\n' "Done. Clients pick up $LAN_ROUTER_IP as DNS when their DHCP lease renews."
