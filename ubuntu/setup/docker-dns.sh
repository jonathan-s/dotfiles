#!/usr/bin/env bash
# docker-dns.sh — point Docker containers at the router's DNS, Dokku-aware.
#
# The daemon-wide "dns" setting only affects containers created afterwards, and
# restarting docker does not rewrite an existing container's resolv.conf. So on
# a Dokku host the apps are recreated instead, which is what actually makes them
# pick the new resolver up.
#
#   sudo bash ubuntu/setup/docker-dns.sh
#
# Values come from ubuntu/hosts/<host>.sh via ubuntu/lib/host.sh (gitignored),
# because this repository is public:
#
#   repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
#   . "$repo/ubuntu/lib/host.sh"
#
# Idempotent: re-running is a no-op once daemon.json is correct.

set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=/dev/null  # gitignored, machine-local
. "$repo/ubuntu/lib/host.sh"

ROUTER_DNS=$LAN_ROUTER_IP
FALLBACK_DNS=${FALLBACK_DNS:-8.8.8.8}
DAEMON_JSON=/etc/docker/daemon.json

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ─── 0. Preconditions ────────────────────────────────────────────────────────
command -v docker > /dev/null 2>&1 || {
	warn "Docker not installed — nothing to configure."
	exit 1
}
command -v python3 > /dev/null 2>&1 || {
	warn "python3 required for JSON handling."
	exit 1
}

# ─── 1. Write / update daemon.json ───────────────────────────────────────────
info "Ensuring $DAEMON_JSON sets dns=[$ROUTER_DNS, $FALLBACK_DNS]..."

RESULT=$(sudo python3 - "$ROUTER_DNS" "$FALLBACK_DNS" "$DAEMON_JSON" <<'PYEOF'
import json, sys

router, fallback, path = sys.argv[1], sys.argv[2], sys.argv[3]
new_dns = [router, fallback]

try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError as e:
    print(f"ERROR: existing {path} is invalid JSON: {e}")
    sys.exit(1)

if data.get("dns") == new_dns:
    print("UNCHANGED")
else:
    data["dns"] = new_dns
    data.setdefault("live-restore", True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("CHANGED")
PYEOF
)

case "$RESULT" in
	CHANGED) ok "daemon.json updated." ;;
	UNCHANGED) ok "daemon.json already correct — nothing to do." ;;
	ERROR:*)
		warn "$RESULT"
		exit 1
		;;
	*) warn "Unexpected result from config step: '$RESULT'" ;;
esac

# ─── 2. Apply to running apps ───────────────────────────────────────────────
# Only worth doing when daemon.json actually changed.
if [ "$RESULT" = CHANGED ]; then
	if command -v dokku > /dev/null 2>&1; then
		info "Recreating Dokku apps so they pick up the new DNS..."
		# `dokku apps:list` prints a header line first; skip it.
		APPS=$(sudo dokku apps:list 2> /dev/null | sed '1d' | grep -v '^$')
		if [ -z "$APPS" ]; then
			warn "No Dokku apps found — nothing to recreate."
		else
			while IFS= read -r APP; do
				info "  restarting $APP..."
				sudo dokku ps:restart "$APP" > /dev/null 2>&1 &&
					ok "  $APP recreated." ||
					warn "  failed to recreate $APP (is it deployed?)."
			done <<< "$APPS"
		fi
	else
		warn "Dokku not detected — existing non-Dokku containers keep their old DNS."
		warn "Recreate them with:  docker restart <container>"
	fi
fi

# ─── 3. Verify ───────────────────────────────────────────────────────────────
info "Current daemon.json DNS setting:"
sudo cat "$DAEMON_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("  dns =", d.get("dns"))' ||
	warn "Could not read $DAEMON_JSON."

info "Checking the router's DNS is reachable (${ROUTER_DNS}:53)..."
if timeout 3 bash -c "echo > /dev/tcp/${ROUTER_DNS}/53" 2> /dev/null; then
	ok "Router DNS reachable."
else
	warn "Cannot reach ${ROUTER_DNS}:53 — double-check the router is serving DNS."
fi

printf '\n%s\n' "Done. Containers use ${ROUTER_DNS} for DNS (fallback ${FALLBACK_DNS})."
