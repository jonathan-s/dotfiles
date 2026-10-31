#!/bin/sh
# System-level settings that need sudo. Only run with --system.
set -eu

# Power management. Hibernation and the sleep image are deliberately absent:
# this is an Apple Silicon machine and they are meaningless here.
sudo pmset -a lidwake 1
sudo pmset -a autorestart 1
sudo pmset -a displaysleep 15
sudo pmset -c sleep 0
sudo pmset -b sleep 5

# Login window: host info under the clock, input menu on the boot screen.
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true

# Spotlight: keep indexing on for the main volume and skip unknown volumes.
sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"
sudo mdutil -i on / > /dev/null 2>&1 || true

# Show /Volumes in Finder.
sudo chflags nohidden /Volumes 2> /dev/null || true

# Verify before enabling: reported to warn on every restart rather than hang.
# sudo systemsetup -setrestartfreeze on
