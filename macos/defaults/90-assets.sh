#!/bin/sh
# Non-defaults assets: plist imports, file copies and symlinks.
#
# Runner conventions used here:
#   # stamp-skip: true           run on every apply (cheap, self-healing)
#   # expect-file: <src>|<dest>  --check compares a copied file with its source
#   # expect-link: <dest>|<src>  --check verifies a symlink target
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
assets="$repo/macos/assets"

# Rectangle: whole-domain import. cfprefsd owns the live preference file, so an
# import rather than a symlink. Rectangle reads the values on its next launch.
defaults import com.knollsoft.Rectangle "$assets/rectangle.plist"

# Swedish Svorak keyboard layout.
mkdir -p "$HOME/Library/Keyboard Layouts"
cp "$assets/Swedish-Svorak.keylayout" "$HOME/Library/Keyboard Layouts/Swedish-Svorak.keylayout"

# VS Code writes these files in place and keeps symlinks intact, verified on
# macOS 27 by toggling a setting and a keybinding: the link survived, the repo
# file kept its inode, JSONC comments and trailing commas were preserved.
link() {
	src=$1
	dest=$2
	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		return 0
	fi
	mkdir -p "$(dirname -- "$dest")"
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		backup="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
		rel=${dest#"$HOME"/}
		mkdir -p "$backup/$(dirname -- "$rel")"
		mv -- "$dest" "$backup/$rel"
		echo "assets: backed up $dest -> $backup/$rel" >&2
	fi
	ln -s -- "$src" "$dest"
}

code_user="$HOME/Library/Application Support/Code/User"
link "$assets/vscode/settings.json" "$code_user/settings.json"
link "$assets/vscode/keybindings.json" "$code_user/keybindings.json"
link "$assets/snippets/rust.json" "$code_user/snippets/rust.json"

# stamp-skip: true
# expect-file: ../assets/Swedish-Svorak.keylayout|${HOME}/Library/Keyboard Layouts/Swedish-Svorak.keylayout
# expect-link: ${HOME}/Library/Application Support/Code/User/settings.json|../assets/vscode/settings.json
# expect-link: ${HOME}/Library/Application Support/Code/User/keybindings.json|../assets/vscode/keybindings.json
# expect-link: ${HOME}/Library/Application Support/Code/User/snippets/rust.json|../assets/snippets/rust.json
