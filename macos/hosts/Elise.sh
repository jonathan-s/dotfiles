#!/bin/sh
# Per-host settings for Elise. Applied by defaults.sh --system, because every
# line here needs sudo. Copy this file to hosts/<ComputerName>.sh for a new Mac.
set -eu

sudo scutil --set ComputerName "Elise"
sudo scutil --set HostName "Elise"
sudo scutil --set LocalHostName "Elise"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "Elise"

# Time zone. Language and locale are intentionally not set here: they are
# personal rather than per-machine, and defaults.sh must not fight the user.
sudo systemsetup -settimezone "Europe/Berlin" > /dev/null
