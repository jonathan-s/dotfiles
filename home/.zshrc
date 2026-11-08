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

# nvm, which has to be sourced rather than exported. The Homebrew formula and a
# plain ~/.nvm install put it in different places, so take whichever exists.
export NVM_DIR="$HOME/.nvm"
for _nvm in "${HOMEBREW_PREFIX:-}/opt/nvm/nvm.sh" "$NVM_DIR/nvm.sh"; do
	[ -n "$_nvm" ] && [ -s "$_nvm" ] && { . "$_nvm"; break; }
done
unset _nvm

# bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# direnv: load .envrc when entering a directory.
command -v direnv > /dev/null 2>&1 && eval "$(direnv hook zsh)"

# fzf: Ctrl-R history, Alt-C cd, Ctrl-T file picker, plus completion.
command -v fzf > /dev/null 2>&1 && eval "$(fzf --zsh)"

# zoxide: `z <partial path>` to jump around.
command -v zoxide > /dev/null 2>&1 && eval "$(zoxide init zsh)"

# zsh-autosuggestions, then syntax highlighting, which has to be sourced last
# so it can wrap the widgets the other plugins define. HOMEBREW_PREFIX is set by
# brew shellenv in .zshenv, so this is the same path on macOS and Linuxbrew.
if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
	_plugin="$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
	[ -f "$_plugin" ] && source "$_plugin"
	_plugin="$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
	[ -f "$_plugin" ] && source "$_plugin"
	unset _plugin
fi

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
for file in ~/.{path,exports,aliases,functions}; do
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

# Correct spelling mistakes in your commands. Deliberate on a Mac, actively
# unwanted on the server, where the shell is mostly used for exact commands.
if [[ $OSTYPE == darwin* ]]; then
	setopt CORRECT
	setopt CORRECT_ALL
fi

# Allow [ or ] whereever you want
unsetopt nomatch
