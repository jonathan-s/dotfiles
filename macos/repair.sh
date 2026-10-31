#!/bin/sh
# One-off repairs. Expensive and occasionally disruptive, so never part of a
# normal apply; run these by hand when Finder's "Open With" menu or Spotlight
# search results actually misbehave.
#
#   ./macos/repair.sh launchservices
#   ./macos/repair.sh spotlight

set -eu

case ${1:-} in
	launchservices)
		echo "rebuilding the Launch Services database"
		/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
			-kill -r -domain local -domain system -domain user
		;;
	spotlight)
		echo "reindexing / (this takes a while)"
		sudo mdutil -i on / > /dev/null
		sudo mdutil -E /
		;;
	*)
		echo "usage: $0 {launchservices|spotlight}" >&2
		exit 2
		;;
esac
