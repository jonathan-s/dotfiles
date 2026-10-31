#!/bin/sh
# Settings whose key names or semantics are still unverified on macOS 27.
# Not part of a normal apply; run with: ./macos/defaults.sh --only 80-experimental
set -eu

# WindowManager.HideDesktop replaced EnableStandardClickToShowDesktop somewhere
# between macOS 14 and 27. Reading it here gives 1, which is the "click the
# wallpaper to reveal the desktop" behaviour; setting it to false is unverified.
defaults write com.apple.WindowManager HideDesktop -bool false

# Tiling feedback; only relevant if tiling is ever enabled again.
defaults write com.apple.WindowManager TilingWindowPreviewDelay -float 0
defaults write com.apple.WindowManager ShowTilingSnapDividers -bool false
