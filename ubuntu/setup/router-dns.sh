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

# list_has checks whether a UCI list already contains a value (uci show prints
# lists space- or newline-separated, so a fixed-string grep is sufficient).
# add_list only appends when missing.
list_has() { # section option value
	uci -q show dhcp 2> /dev/null | grep -qF "$2='$3'"
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
info "Ensuring *.$LAN_DOMAIN and *.$PUBLIC_DOMAIN resolve to $LAN_SERVER_IP..."
add_list 'dhcp.@dnsmasq[0]' local "/$DOMAIN_SUFFIX/"
add_list 'dhcp.@dnsmasq[0]' local "/$LAN_DOMAIN/"
add_list 'dhcp.@dnsmasq[0]' local "/$PUBLIC_DOMAIN/"
add_list 'dhcp.@dnsmasq[0]' address "/$LAN_DOMAIN/$LAN_SERVER_IP"
add_list 'dhcp.@dnsmasq[0]' address "/$PUBLIC_DOMAIN/$LAN_SERVER_IP"
ok "Wildcard entries ensured."

# ─── 3. Advertise the router as DNS to DHCP clients ─────────────────────────
info "Making LAN DHCP advertise $LAN_ROUTER_IP as DNS (option 6)..."
add_list 'dhcp.lan' dhcp_option "6,$LAN_ROUTER_IP"
ok "DHCP DNS advertisement ensured."

# ─── 4. Commit and restart ───────────────────────────────────────────────────
info "Committing UCI config and restarting dnsmasq..."
uci commit dhcp
/etc/init.d/dnsmasq restart > /dev/null 2>&1
sleep 2
ok "dnsmasq restarted."

# ─── 5. Verify ───────────────────────────────────────────────────────────────
info "Verifying local wildcard DNS..."
LOCAL=$(dig +short "test.$LAN_DOMAIN" @127.0.0.1 2> /dev/null | tail -n1)
if [ "$LOCAL" = "$LAN_SERVER_IP" ]; then
	ok "test.$LAN_DOMAIN → $LOCAL"
else
	warn "Local wildcard check failed: got '$LOCAL', expected $LAN_SERVER_IP."
fi

info "Verifying external DNS..."
EXTERNAL=$(dig +short example.com @127.0.0.1 2> /dev/null | tail -n1)
if [ -n "$EXTERNAL" ]; then
	ok "External DNS working (example.com → $EXTERNAL)"
else
	warn "External DNS not resolving — check upstream WAN DNS."
fi

printf '\n%s\n' "Done. Clients pick up $LAN_ROUTER_IP as DNS when their DHCP lease renews."
