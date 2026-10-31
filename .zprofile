# Login shells only. Anything needed by every zsh belongs in .zshenv.

# pyenv shims for login shells; interactive shells get them from .zshrc too.
if command -v pyenv > /dev/null 2>&1; then
	eval "$(pyenv init --path)"
fi
