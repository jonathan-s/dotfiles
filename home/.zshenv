# Environment for every zsh, login or not.
# Interactive-only things (oh-my-zsh, completions, aliases) belong in .zshrc.

# Homebrew (Apple Silicon first, then Intel for older machines).
if [[ -x /opt/homebrew/bin/brew ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
	eval "$(/usr/local/bin/brew shellenv)"
fi

# Some brew env variables we want to use.
# See https://docs.brew.sh/Manpage#environment
export HOMEBREW_DISPLAY_INSTALL_TIMES=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_AUTOREMOVE=1

# macOS adds strange files when tarring a directory.
# https://apple.stackexchange.com/questions/75989
export COPYFILE_DISABLE=1

# Binaries installed outside of the package managers.
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Python: pyenv manages the interpreters, .zshrc adds the shims interactively.
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Node: bun for the toolchain, nvm is loaded in .zshrc because it is a function.
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && export PATH="$BUN_INSTALL/bin:$PATH"

# Java
[[ -d /opt/homebrew/opt/openjdk/bin ]] && export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Visual Studio Code CLI
[[ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]] && \
	export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# 2026-10 eMudhra CA incident: legacy pip (<26) ignores the macOS Keychain and
# verifies only against its own vendored certifi, which can never be fixed on
# Python <3.10 (pip>=26.2.2 requires 3.10+). Point it at the system bundle,
# which has been patched to drop emSign ECC Root CA - G3 and AAA Certificate
# Services. Ignored by pip >= 26 (which uses truststore + Keychain deny rules).
export PIP_CERT=/etc/ssl/cert.pem

# libpq (Homebrew, keg-only) — lets psycopg's pure-Python ctypes binding find
# libpq.dylib for host-side Django/pytest runs. Not on the default dyld path.
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/opt/libpq/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
