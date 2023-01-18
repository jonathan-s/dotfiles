#! /bin/zsh

eval $(/usr/local/bin/brew shellenv)

# Some brew env variables we want to use.
# See https://docs.brew.sh/Manpage#environment
export HOMEBREW_DISPLAY_INSTALL_TIMES=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_AUTOREMOVE=1

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# Make sure the ssh agent is running so we only need to add keys once.
eval $(ssh-agent)

# Add Visual Studio Code (code)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Autojump; https://github.com/wting/autojump
# installed through brew.
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

# Options

# Case-insensitive globbing (used in pathname expansion)
setopt NO_CASE_GLOB

# shell will automatically change directory even if you forget cd.
setopt AUTO_CD

# Extended history of commands
setopt EXTENDED_HISTORY

# Share history across sessions
setopt SHARE_HISTORY

# append to history
setopt APPEND_HISTORY

# adds commands as they are typed, not at shell exit
setopt INC_APPEND_HISTORY

# expire duplicates first
# setopt HIST_EXPIRE_DUPS_FIRST
# do not store duplications
setopt HIST_IGNORE_DUPS
# ignore duplicates when searching
# setopt HIST_FIND_NO_DUPS
# removes blank lines from history
setopt HIST_REDUCE_BLANKS

# correct spelling mistakes in your commands
setopt CORRECT
setopt CORRECT_ALL

# Allow [ or ] whereever you want
unsetopt nomatch
