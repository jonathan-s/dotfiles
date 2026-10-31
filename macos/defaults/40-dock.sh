#!/bin/sh
# Dock, hot corners and window management.
set -eu

# Dock: size (machine value), scale effect, no minimise-into-app-icon.
defaults write com.apple.dock tilesize -int 52
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock minimize-to-application -bool false

# Spring loading for Dock items, open-app indicators.
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
defaults write com.apple.dock show-process-indicators -bool true

# No window grouping in Mission Control, Spaces never reorder by use.
defaults write com.apple.dock expose-group-by-app -bool false
defaults write com.apple.dock mru-spaces -bool false

# Autohide, without delay or a long animation; translucent hidden icons.
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2
defaults write com.apple.dock showhidden -bool true

# No recent applications, no magnification.
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock magnification -bool false

# Hot corners: top left Mission Control, top right Desktop, bottom left screen saver.
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 4
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0

# macOS 15+ window tiling is off: Rectangle owns that job.
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
