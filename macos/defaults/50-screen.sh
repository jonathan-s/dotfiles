#!/bin/sh
# Screen: screensaver password, screenshots.
set -eu

# Require the password immediately after sleep or screen saver.
defaults write com.apple.screensaver askForPassword -bool true
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Screenshots: Desktop, PNG, no window shadow, no floating thumbnail.
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture show-thumbnail -bool false
