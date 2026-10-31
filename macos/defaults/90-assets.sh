#!/bin/sh
# Non-defaults assets: whole-domain plist imports and files copied into place.
#
# The runner understands two conventions in this file:
#   # stamp-include: <path>      include an asset in the module's change hash
#   # expect-file: <src>|<dest>   --check compares dest with src (copy drift)
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
assets="$repo/macos/assets"

# Rectangle: whole-domain import. cfprefsd owns the live preference file, so
# this is an import rather than a symlink. Rectangle reads the values on its
# next launch, so quit and reopen it after changing the plist.
defaults import com.knollsoft.Rectangle "$assets/rectangle.plist"

# Swedish Svorak keyboard layout.
mkdir -p "$HOME/Library/Keyboard Layouts"
cp "$assets/Swedish-Svorak.keylayout" "$HOME/Library/Keyboard Layouts/Swedish-Svorak.keylayout"

# Deliberately not installed yet: assets/vscode/{settings,keybindings}.json and
# assets/snippets/. The repo copies differ from the live files, so copying them
# would clobber the editor. See the deferred todo item.

# stamp-include: ../assets/rectangle.plist
# stamp-include: ../assets/Swedish-Svorak.keylayout
# expect-file: ../assets/Swedish-Svorak.keylayout|${HOME}/Library/Keyboard Layouts/Swedish-Svorak.keylayout
