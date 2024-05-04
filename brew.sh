#!/usr/bin/env bash

# Ask for sudo password
sudo -v

# Some brew env variables we want to use for this script.
export HOMEBREW_DISPLAY_INSTALL_TIMES=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_AUTOREMOVE=1

# Install command-line tools using Homebrew.
sudo softwareupdate --install-rosetta --agree-to-license

# Install brew.
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed
# Install a modern version of Bash.
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install `wget` with IRI support.
brew install wget

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim
brew install grep
brew install openssh
brew install screen
brew install nmap

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install other useful binaries.
# search tool optimized for programmers
brew install ack
brew install git
brew install git-lfs
brew install git-quick-stats
brew install cask
brew install imagemagick
# 7-Zip (high compression file archiver) implementation
brew install p7zip
# Monitor data's progress through a pipe
brew install pv
# Readline wrapper: adds readline support to tools that lack it
brew install rlwrap
# Add a public key to a remote machine's authorized_keys file
brew install ssh-copy-id
# New zlib (gzip, deflate) compatible compressor
brew install zopfli

brew install ansible
brew install asciidoctor
# Shell extension to jump to frequently used directories
brew install autojump
# Tool for generating GNU Standards-compliant Makefiles
brew install automake
brew install cmake
# gives examples of man pages
brew install cheat
brew install dep
brew install direnv
brew install docker-machine
brew install ffmpeg
# filewatching utility
brew install fswatch
brew install gcutil
brew install geckodriver
# Graph visualization software from AT&T and Bell Labs
brew install graphviz
brew install haproxy
brew install heroku/brew/heroku
brew install htop
brew install httpie
brew install httrack
brew install mitmproxy
# app tools like appstore
brew install mas
mas install 1256503523            # System Indicators

# node version manager
brew node
brew install nvm
mkdir -p ~/.nvm
brew install pandoc
# Data loading tool for PostgreSQL
brew install pgloader
brew install pyenv
brew install pyenv-virtualenv
brew install rabbitmq
brew install redis
brew install ripgrep
brew install tree
brew install yarn

brew tap homebrew/cask-versions

# command palatte for all applications
brew install shortcat
brew install --cask 1password6
brew install --cask anki
brew install --cask alfred
brew install --cask bitwarden
# Screen color temperature controller
brew install --cask flux
# Move and resize windows with ease
brew install --cask spectacle
# E-books management software
brew install --cask calibre
# combining pdfs
brew install --cask combine-pdfs
# excellent backup utility
brew install --cask carbon-copy-cloner
brew install --cask dbeaver-community
brew install --cask discord
brew install --cask dropbox
# visualize what takes most data
brew install --cask disk-inventory-x
brew install --cask docker
brew install --cask exodus
brew install --cask firefox
brew install --cask firefox-developer-edition
# Open-source video transcoder
brew install --cask handbrake
# HTTP and GraphQL Client
brew install --cask insomnia
brew install --cask iterm2
# Open-source screen recorder built with web technology
brew install --cask kap
# Cross platform presentation and productivity app
brew install --cask keybase
brew install --cask lynx
brew install --cask libreoffice
brew install --cask little-snitch
brew install --cask mullvadvpn
brew install --cask obsidian
brew install --cask postgres-unofficial
brew install --cask postico
brew install --cask protonvpn
brew install --cask proton-mail
brew install --cask proton-mail-bridge
brew install --cask proton-drive
brew install --cask rectangle
brew install --cask selfcontrol
brew install --cask signal
# simple pdf reader
brew install --cask skim
brew install --cask slack
brew install --cask steam
brew install --cask telegram
brew install --cask transmission
brew install --cask tunnelblick
brew install --cask visual-studio-code
brew install --cask vlc
brew install --cask webtorrent
brew install --cask xquartz

# Remove outdated versions from the cellar.
brew cleanup

# Installation of other utilities for the system
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
