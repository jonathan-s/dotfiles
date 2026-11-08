#!/usr/bin/env bash
# expire-history.sh — drop shell history entries older than N days.
#
# Supports the two timestamped history formats:
#   zsh (EXTENDED_HISTORY):  ": <epoch>:<dur>;<command>"
#   bash (HISTTIMEFORMAT):   "#<epoch>" timestamp line preceding the command
#
# It prunes whichever file $HISTFILE points at (default ~/.zsh_history).
# Legacy lines written before timestamps were enabled are kept untouched.
#
# Usage:   ~/bin/expire-history.sh [DAYS]     (default 90)
# Intended: run daily from cron (installed by ubuntu/setup.sh).
set -euo pipefail

DAYS="${1:-90}"
HIST="${HISTFILE:-$HOME/.zsh_history}"

[ -f "$HIST" ] || exit 0
[ -w "$HIST" ] || exit 0

cutoff="$(date -d "${DAYS} days ago" +%s 2>/dev/null)" || exit 0

awk -v c="$cutoff" '
  # zsh EXTENDED_HISTORY line — self-contained ": epoch:duration;command"
  /^: [0-9]+:/ { ts=$2+0; keep=(ts>=c); if (keep) print; next }
  # bash timestamp comment line
  /^#[0-9]+/   { seen=1; ts=substr($0,2)+0; keep=(ts>=c); if (keep) print; next }
  # bash command line following a timestamp, or legacy line with no timestamps yet
  { if (!seen || keep) print }
' "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"

echo "expire-history: dropped entries older than ${DAYS} days (${HIST})"
