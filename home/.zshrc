# Interactive zsh. Environment shared by all shells lives in .zshenv.

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="gnzh"
plugins=(git dotenv)
source "$ZSH/oh-my-zsh.sh"

# pyenv: shims, completions and the pyenv shell function.
command -v pyenv > /dev/null 2>&1 && eval "$(pyenv init -)"

# Ghostty shell integration (emits OSC 7 cwd so Cmd+click on file paths opens).
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
	source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi

# nvm, which has to be sourced rather than exported.
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# Reuse a single ssh-agent instead of spawning one per shell.
# macOS normally provides one via launchd, which is why SSH_AUTH_SOCK is often
# already set; the cache file covers shells started outside that session.
_ssh_agent_alive() {
	[[ -S ${SSH_AUTH_SOCK:-} ]] || return 1
	# exit 1 means "agent is up but holds no keys", which is still alive.
	ssh-add -l > /dev/null 2>&1
	(( $? <= 1 ))
}

if ! _ssh_agent_alive; then
	_ssh_agent_env="${XDG_CACHE_HOME:-$HOME/.cache}/ssh-agent.env"
	[[ -r "$_ssh_agent_env" ]] && source "$_ssh_agent_env"
	if ! _ssh_agent_alive; then
		eval "$(ssh-agent -s)" > /dev/null
		mkdir -p "${_ssh_agent_env:h}"
		(umask 077; print -r -- "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK"$'\n'"export SSH_AGENT_PID=$SSH_AGENT_PID" >| "$_ssh_agent_env")
	fi
	unset _ssh_agent_env
fi
unfunction _ssh_agent_alive

# User dotfiles, loaded last so they win over anything above.
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for settings you don’t want to commit.
for file in ~/.{path,exports,aliases,functions,extra}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file

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
