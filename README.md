# Jonathan's dotfiles

Personal dotfiles for macOS, zsh and a handful of editors. Everything that belongs in `$HOME` lives under `home/` and is symlinked into place, packages are declared in a `Brewfile`, and the macOS preferences are split into small modules that can be checked.

Originally forked from [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles); most of it has since been rewritten. Licensed MIT (see `LICENSE-MIT.txt`).

**Warning:** these are my settings. If you want to use them, fork the repo, read the code and remove what you don't need. Use at your own risk.

## Contents

- [Jonathan's dotfiles](#jonathans-dotfiles)
  - [Contents](#contents)
  - [What is in here](#what-is-in-here)
  - [Installing a new machine](#installing-a-new-machine)
  - [Updating](#updating)
  - [Checking that things are in sync](#checking-that-things-are-in-sync)
  - [Packages](#packages)
  - [Editors](#editors)
  - [macOS preferences](#macos-preferences)
  - [Local overrides](#local-overrides)
  - [Design notes](#design-notes)
  - [Acknowledgements](#acknowledgements)

## What is in here

| Path              | What it does                                                                    |
| ----------------- | ------------------------------------------------------------------------------- |
| `home/`           | every file that belongs in `$HOME`, symlinked by `bootstrap`                    |
| `bootstrap`       | links `home/` into `$HOME`, prunes dead links, reports drift                    |
| `install`         | cold-start orchestrator: preflight, packages, tools, links, login shell         |
| `Brewfile`        | `brew bundle` manifest: formulae, casks, VS Code extensions, cargo/npm/uv tools |
| `macos/`          | macOS preferences (`defaults/`), per-host values (`hosts/`), assets, repairs    |
| `.githooks/`      | pre-commit guard against committing credentials                                 |
| `.python-version` | Python version the `tools` stage installs                                       |

## Installing a new machine

Install [Homebrew](https://brew.sh/) first, then:

```bash
git clone https://github.com/jonathan-s/dotfiles.git && cd dotfiles
./install
```

`./install` is safe to re-run. It installs packages from the `Brewfile`, clones oh-my-zsh,
installs the pinned Python and rustup, links the dotfiles and points the login shell at zsh.
On macOS it also applies the preferences in `macos/defaults/`.

## Updating

`./bootstrap` it only relinks the dotfiles and applies preference modules that changed:

```bash
git pull && ./bootstrap
```

It also sets `core.hooksPath` to `.githooks/`, so the credential guard is active in this repo
without extra setup.

## Checking that things are in sync

```bash
./bootstrap --report
```

It reports the following listed items and then exits:

- links that are missing, point elsewhere, or are shadowed by a real file,
- links whose source file has left the repository,
- uncommitted changes in the repository (see [Design notes](#design-notes)),
- macOS preferences that drifted from `macos/defaults/`.

Narrower checks exist too:

```bash
./bootstrap --dry-run     # what linking would change, without changing it
./bootstrap --verify      # link health only
./install --check         # packages and tools only
./macos/defaults.sh --check   # macOS preferences only
```

## Packages

`Brewfile` is the manifest. After installing something new, capture it:

```bash
brew bundle dump --file=Brewfile --force
```

`./install --check` reports what is in the manifest but missing from the machine.
Homebrew 7 disables `brew bundle dump --describe`.

## Editors

VS Code settings, keybindings and snippets are symlinked into `~/Library/Application Support/Code/User/`, so edits in the editor are edits in the repo. VS Code writes these files in place, which keeps the symlink, the JSONC comments and the trailing commas intact.

Machine-specific editor settings do not belong in the repo. The project that needs its own interpreter path sets it in that project's `.vscode/settings.json` instead.

Zed and vim are configured through `home/.config/zed/settings.json` and `home/.vimrc`.

## macOS preferences

`macos/defaults.sh` applies the modules in `macos/defaults/`:

| Command               | Effect                                                                    |
| --------------------- | ------------------------------------------------------------------------- |
| `./macos/defaults.sh` | apply modules whose file changed since the last run                       |
| `--check`             | compare modules with this Mac, change nothing                             |
| `--only 30-finder`    | apply one module                                                          |
| `--all`               | apply everything, ignoring the change stamps                              |
| `--system`            | also apply `70-system` (Power Management, login window) and the host file |
| `--list`              | list modules in order                                                     |

`70-system` and `hosts/<ComputerName>.sh` need sudo and are never run implicitly. The experimental module `80-experimental` only runs when named with `--only`. Expensive one-off fixes live in `macos/repair.sh` (`launchservices`, `spotlight`) and are never automatic.

Application assets are handled by `macos/defaults/90-assets.sh`: the Rectangle preferences are imported, the Svorak keyboard layout is copied, and the VS Code files are symlinked.

## Local overrides

`~/.path` is sourced with the other dotfiles, so extra `$PATH` entries can live there without touching the repo:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Design notes

- **Symlinks over copies.** editing the live file is editing the repo. The catch is that app edits land as uncommitted changes — that is what `./bootstrap --report` surfaces.
- **Preferences are code, application state is not.** `defaults write` lines live in the repo; whole-domain plists are imported; the VS Code files are symlinked; anything that is regenerated (a `Rectangle` export, a `brew bundle dump`) is captured deliberately.
- **Nothing needs sudo implicitly.** Package installs and `bootstrap` run as your user; the sudo-only preferences are behind `--system`, and `repair.sh` is manual.
- **Credentials are guarded.** `.githooks/pre-commit` refuses to commit anything shaped like a token or a private key. The git identity is inlined in `home/.gitconfig`, on purpose.

## Acknowledgements

This repository started as a fork of [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles), and the shape of the original `.macos` script is still recognisable in `macos/defaults/`.

- [Mathias Bynens](https://mathiasbynens.be/) for the original dotfiles and the macOS defaults
  collection.
- [Kevin Suttle](https://github.com/kevinSuttle/macOS-Defaults) and the macOS-Defaults project for documenting the defaults.
- [yannbertrand/macos-defaults](https://github.com/yannbertrand/macos-defaults) for keeping a maintained, per-OS-verified list of `defaults` commands.
- The macOS setup notes from [@ptb](https://github.com/ptb/mac-setup),
  [Ben Alman](https://github.com/cowboy/dotfiles),
  [Cătălin Mariș](https://github.com/alrra/dotfiles),
  [Gianni Chiappetta](https://github.com/gf3/dotfiles) and
  [Nicolas Gallagher](https://github.com/necolas/dotfiles).

Suggestions and improvements are [welcome](https://github.com/jonathan-s/dotfiles/issues).
