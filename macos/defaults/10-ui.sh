#!/bin/sh
# Global UI: NSGlobalDomain, accessibility, menu bar clock.
set -eu

# Disable transparency in the menu bar and elsewhere.
defaults write com.apple.universalaccess reduceTransparency -bool true

# Highlight colour, sidebar icon size, always-visible scrollbars.
defaults write NSGlobalDomain AppleHighlightColor -string "0.764700 0.976500 0.568600"
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# Focus ring animation, toolbar title rollover, window resize speed.
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false
defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Save and print panels expanded; save to disk rather than iCloud.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Quit the printer app once the queue is done.
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# No quarantine prompt for downloaded applications.
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Control characters visible; resume disabled, on the right domain this time.
defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
defaults write com.apple.loginwindow TALLogoutSavesState -bool false

# Help Viewer windows in non-floating mode.
defaults write com.apple.helpviewer DevMode -bool true

# Web inspector in embedded web views (unrelated to Safari's own menu).
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# Autocorrect family off, including the 26-era text completion.
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false

# Inline file extensions everywhere.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Menu bar: date, no seconds.
defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM HH:mm"
defaults write com.apple.menuextra.clock ShowSeconds -bool false

# Menu bar item spacing, useful on notched displays. -currentHost, so not checked.
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 4
