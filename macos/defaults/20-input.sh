#!/bin/sh
# Trackpad, mouse and keyboard.
set -eu

# Tap to click, plus two-finger secondary click (built-in trackpad).
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Same for a Bluetooth trackpad, and for the login window.
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Classic (non-natural) scrolling.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Full keyboard access, i.e. Tab works in every dialog.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Ctrl+scroll to zoom, following the keyboard focus.
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

# Hold-a-key repeats instead of opening the accent popover.
# Tradeoff: on a Swedish layout this also removes accents from long-press.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat. These are the values the machine actually runs.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 35

# Drag a window from anywhere with Ctrl+Cmd.
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
