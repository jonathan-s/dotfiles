#!/bin/sh
# macOS preferences, split into modules under macos/defaults/.
#
#   ./macos/defaults.sh                 apply modules whose file changed since last run
#   ./macos/defaults.sh --check         report drift, change nothing; exit 1 on drift
#   ./macos/defaults.sh --only 30-finder --check
#   ./macos/defaults.sh --all           apply every module, ignore the change stamps
#   ./macos/defaults.sh --system        also apply 70-system (needs sudo)
#   ./macos/defaults.sh --no-restart    skip the Dock/Finder/SystemUIServer relaunch
#   ./macos/defaults.sh --list          list the modules in order
#
# Stamps live in ~/.cache/dotfiles/macos-defaults, so a converged machine does
# nothing on ./bootstrap and a changed module re-applies exactly once.
#
# A module can declare two extra conventions:
#   # stamp-include: <path>      asset that belongs in the module's change hash
#   # expect-file: <src>|<dest>  copied file that --check compares against src
#
# ./macos/repair.sh holds the expensive one-off fixes (Spotlight reindex,
# Launch Services rebuild); they are never part of a normal apply.

set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
modules_dir="$repo/defaults"
stamp_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/macos-defaults"
mode=apply
only=
restart=1
run_system=0
force_all=0
quiet=0
failed=
applied=0
skipped=0
drift=0
restart_needed=0

usage() {
	cat <<'EOF'
Usage: ./macos/defaults.sh [--check] [--only <module>] [--all] [--system] [--no-restart] [--list]

  (no flags)   apply modules whose file changed since the last run
  --check      compare modules with this Mac, change nothing, exit 1 on drift
  --only NAME  limit to one module, e.g. --only 30-finder
  --all        apply everything, ignoring the change stamps
  --system     also run 70-system (sudo: pmset, hostname, timezone)
  --no-restart relaunch nothing
  --list       list modules in apply order
EOF
}

while [ $# -gt 0 ]; do
	case $1 in
		--check) mode=check ;;
		--apply) mode=apply ;;
		--list) mode=list ;;
		--only) only=$2; shift ;;
		--all) force_all=1 ;;
		--system) run_system=1 ;;
		--no-restart) restart=0 ;;
		--quiet) quiet=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "macos/defaults.sh: unknown option: $1" >&2
			usage >&2
			exit 2
			;;
	esac
	shift
done

say() {
	[ "$quiet" -eq 1 ] || echo "$@"
}

module_names() {
	for file in "$modules_dir"/*.sh; do
		name=$(basename "$file" .sh)
		case $name in
			70-system) [ "$run_system" -eq 1 ] || continue ;;
			80-experimental) continue ;;
		esac
		echo "$name"
	done
}

# Compare the simple, parseable writes in a module with the live preferences.
# Anything the parser cannot model (arrays, dicts, -currentHost, sudo, PlistBuddy)
# is skipped on purpose rather than reported as drift.
check_file() {
	file=$1
	name=$(basename "$file" .sh)
	dir=$(dirname "$file")

	# Files that are copied into place are compared directly.
	while IFS= read -r spec; do
		[ -n "$spec" ] || continue
		src="$dir/${spec%%|*}"
		dest=$(printf '%s' "${spec#*|}" | sed "s|\${HOME}|$HOME|g")
		if ! cmp -s "$src" "$dest" 2> /dev/null; then
			echo "drift: $name: $dest differs from $(basename "$src")"
			drift=$((drift + 1))
		fi
	done <<EOF
$(sed -n 's/^# expect-file: *//p' "$file")
EOF

	set -f
	while IFS= read -r line; do
		# shellcheck disable=SC2086
		set -- $line
		[ "$#" -ge 5 ] || continue
		domain=$3
		key=$4
		flag=$5
		shift 5
		want=$*
		want=${want#\"}
		want=${want%\"}
		# The modules write ${HOME} literally; the value on disk is expanded.
		want=$(printf '%s' "$want" | sed "s|\${HOME}|$HOME|g")
		current=$(defaults read "$domain" "$key" 2> /dev/null || true)
		if [ -z "$current" ]; then
			echo "drift: $name: $domain $key is unset, want $want"
			drift=$((drift + 1))
			continue
		fi
		case $flag in
			-bool)
				case $current in 1) current=true ;; 0) current=false ;; esac
				;;
			-int | -float)
				if awk -v a="$current" -v b="$want" 'BEGIN { exit !(a == b) }'; then
					continue
				fi
				;;
		esac
		if [ "$current" != "$want" ]; then
			echo "drift: $name: $domain $key is $current, want $want"
			drift=$((drift + 1))
		fi
	done <<EOF
$(grep -E '^defaults write [^ ]+ [^ ]+ -(bool|int|float|string) ' "$file" || true)
EOF
}

stamp_sum() {
	file=$1
	dir=$(dirname "$file")
	parts=$(shasum -a 256 "$file")
	while IFS= read -r inc; do
		[ -n "$inc" ] || continue
		parts="$parts
$(shasum -a 256 "$dir/$inc")"
	done <<EOF
$(sed -n 's/^# stamp-include: *//p' "$file")
EOF
	printf '%s\n' "$parts" | shasum -a 256 | awk '{print $1}'
}

apply_file() {
	file=$1
	name=$(basename "$file" .sh)
	if [ -n "$only" ] && [ "$only" != "$name" ]; then
		return 0
	fi
	stamp="$stamp_dir/$name.sha"
	sum=$(stamp_sum "$file")
	if [ "$force_all" -eq 0 ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$sum" ]; then
		skipped=$((skipped + 1))
		return 0
	fi
	say "==> $name"
	if sh "$file"; then
		mkdir -p "$stamp_dir"
		printf '%s\n' "$sum" > "$stamp"
		applied=$((applied + 1))
		# Assets (copied files, plist imports) do not need a Dock relaunch.
		[ "$name" = 90-assets ] || restart_needed=1
	else
		echo "macos/defaults.sh: module failed: $name" >&2
		failed="$failed $name"
	fi
}

restart_apps() {
	for app in Dock Finder SystemUIServer; do
		killall "$app" 2> /dev/null || true
	done
}

case $mode in
	list)
		module_names
		exit 0
		;;
	check)
		for file in "$modules_dir"/*.sh; do
			name=$(basename "$file" .sh)
			# Experimental keys are only checked when asked for by name.
			if [ "$name" = 80-experimental ] && [ "$only" != 80-experimental ]; then
				continue
			fi
			if [ -n "$only" ] && [ "$only" != "$name" ]; then
				continue
			fi
			check_file "$file"
		done
		if [ "$drift" -eq 0 ]; then
			echo "macos defaults: no drift"
		else
			echo "macos defaults: $drift drifted value(s)" >&2
			exit 1
		fi
		;;
	apply)
		for file in "$modules_dir"/*.sh; do
			name=$(basename "$file" .sh)
			case $name in
				70-system) [ "$run_system" -eq 1 ] || continue ;;
				80-experimental) [ "$only" = 80-experimental ] || continue ;;
			esac
			apply_file "$file"
		done
		if [ "$run_system" -eq 1 ]; then
			host=$(scutil --get ComputerName 2> /dev/null || echo unknown)
			host_file="$repo/hosts/$host.sh"
			if [ -f "$host_file" ]; then
				say "==> hosts/$host"
				sh "$host_file" || failed="$failed hosts/$host"
			fi
		fi
		if [ "$restart_needed" -eq 1 ] && [ "$restart" -eq 1 ]; then
			say "restarting Dock, Finder and SystemUIServer"
			restart_apps
		fi
		say "applied $applied module(s), skipped $skipped, $( [ -n "$failed" ] && echo "failed:$failed" || echo "no failures")"
		[ -z "$failed" ] || exit 1
		;;
esac
