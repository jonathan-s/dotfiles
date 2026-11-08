# Jonathan's dotfiles

Personal dotfiles for macOS and Ubuntu, zsh and a handful of editors. Everything that belongs
in `$HOME` lives under `home/` and is symlinked into place, packages are declared in
`brew/Brewfile`, and each platform keeps its own overrides next to it.

Originally forked from [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles); most
of it has since been rewritten.

**Warning:** these are my settings. If you want to use them, fork the repo, read the code and
remove what you don't need. Use at your own risk. This repo is public, so it deliberately
contains no address, account name or credential of mine — see [host values](#host-values).

## Contents

- [Jonathan's dotfiles](#jonathans-dotfiles)
  - [Contents](#contents)
  - [What is in here](#what-is-in-here)
  - [Installing a new machine](#installing-a-new-machine)
  - [Updating](#updating)
  - [Checking that things are in sync](#checking-that-things-are-in-sync)
  - [How the pieces fit](#how-the-pieces-fit)
  - [Host values](#host-values)
  - [Packages](#packages)
  - [Ubuntu](#ubuntu)
  - [Editors](#editors)
  - [macOS preferences](#macos-preferences)
  - [Local overrides](#local-overrides)
  - [Design notes](#design-notes)
  - [Acknowledgements](#acknowledgements)

## What is in here

| Path              | What it does                                                                        |
| ----------------- | ----------------------------------------------------------------------------------- |
| `home/`           | every file that belongs in `$HOME` on any platform, symlinked by `bootstrap`        |
| `macos/`          | macOS only: `home/` overlay, preference modules, per-host values, assets, repairs   |
| `ubuntu/`         | Ubuntu only: `home/` overlay, apt manifest, setup scripts, host values, install kit |
| `brew/`           | `Brewfile` tiers: minimal for every machine, `.dev` and `.macos`, `.linux`          |
| `bin/bundle`      | runs `brew bundle` over the tiers for this platform                                 |
| `bootstrap`       | links `home/` then the platform overlay, prunes dead links, reports drift           |
| `install`         | cold-start orchestrator: preflight, packages, tools, links, platform, login shell   |
| `.githooks/`      | pre-commit guard against committing credentials                                     |
| `.python-version` | Python version the `tools` stage installs                                           |

## Installing a new machine

Install [Homebrew](https://brew.sh/) first, then:

```bash
git clone https://github.com/jonathan-s/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles && ./install
```

`./install` is safe to re-run. It installs the packages in this platform's Brewfile tiers,
clones oh-my-zsh, installs the pinned Python and rustup, links the dotfiles, applies the
platform settings and points the login shell at zsh.

On a fresh Ubuntu box, run the two stages in order instead — apt first, because `install`
assumes Homebrew and a complete host file:

```bash
sudo bash ubuntu/apt/packages.sh        # daemons, system units, login shell, desktop
cp ubuntu/hosts/host.example.sh ubuntu/hosts/$(hostname -s).sh
$EDITOR ubuntu/hosts/$(hostname -s).sh  # see Host values
sudo bash ubuntu/setup/bootstrap.sh     # packages, then ./install, then hostname/sshd/keyboard
```

## Updating

`./bootstrap` only relinks the dotfiles and applies platform modules that changed or have
drifted:

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
- drift in the platform settings: macOS defaults on a Mac, [Ubuntu](#ubuntu) on Linux.

Narrower checks exist too:

```bash
./bootstrap --dry-run     # what linking would change, without changing it
./bootstrap --verify      # link health only
./install --check         # packages, tools, links, platform settings and login shell
./macos/defaults.sh --check   # macOS preferences only
./ubuntu/setup.sh --check     # Ubuntu host values and crontab only
```

## How the pieces fit

Two things decide where a file lives.

**Shared first, platform second.** `bootstrap` links everything in `home/`, then everything in
`macos/home/` or `ubuntu/home/` on top. The overlay wins for a path, so a file is duplicated
only when the two platforms genuinely differ, and a path is still owned by exactly one repo.

**Shared files test their own platform.** A file that is 90% common (`~/.zshrc`, `~/.zshenv`)
carries a small `$OSTYPE` test or an existence check instead of being copied. `~/.gitconfig`
needs neither: `git-delta` is installed on both machines and both use the same ignore file.

## Host values

Nothing in this repo may contain an address, an account name, or a way into my network — it is
public, and a script that describes how to reach this LAN is worse than no script.

The values live in one gitignored file per machine, and every script reads them from there:

```text
ubuntu/hosts/host.example.sh   tracked; the contract, placeholders only
ubuntu/hosts/elementary-holo.sh           local, gitignored, real values
ubuntu/lib/host.sh                        sourced loader
```

`HOST_NAME`, `LOGIN_USER`, `TIMEZONE`, `LAN_SUBNET`, `LAN_ROUTER_IP`, `LAN_SERVER_IP`,
`LAN_DOMAIN`, `PUBLIC_DOMAIN`, `ACME_EMAIL`. Placeholders use documentation ranges
(`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` — RFC 5737) and `example.*` names, so a
forgotten value is obvious in a diff and `./install --check` fails instead of configuring it.

## Packages

`brew/Brewfile` is the minimal tier for every machine. `brew/Brewfile.dev` and
`brew/Brewfile.macos` are the macOS surface, and `brew/Brewfile.linux` is empty by design: what
a server needs from Homebrew is cross-platform, and anything server-exclusive belongs to apt.

`brew bundle` has no `include`, and it only honours the last `--file`, so `bin/bundle`
concatenates this platform's tiers and pipes them in:

```bash
./bin/bundle check
./bin/bundle install
./bin/bundle list --all
```

`install`, `check`, `list` and `upgrade` work that way. `dump`, `add`, `remove` and `cleanup`
need a real file, so after installing something new:

```bash
brew bundle dump --file=brew/Brewfile.macos --force   # then move entries to the right tier
```

`./install --check` reports what is in the manifest but missing from the machine. Homebrew 7
disables `brew bundle dump --describe`.

## Ubuntu

The home server runs Ubuntu and shares the same dotfiles. The split is a rule, not a habit:

| Rule     | Owner                                                                                   |
| -------- | --------------------------------------------------------------------------------------- |
| apt      | server-exclusive and system-level: daemons, systemd units, `/etc`, login shell, desktop |
| Homebrew | toolchain, from the shared `brew/Brewfile`, so both machines install from one list      |

`ubuntu/` holds the parts that only make sense on Linux:

| Path                  | What it does                                                                        |
| --------------------- | ----------------------------------------------------------------------------------- |
| `apt/packages.sh`     | the apt manifest, idempotent                                                        |
| `setup/bootstrap.sh`  | fresh box: apt, `./install`, hostname, sshd, keyboard                               |
| `setup.sh`            | the platform stage: host values and the daily history expiry                        |
| `setup/router-dns.sh` | wildcard LAN DNS; runs on the OpenWrt router, takes its values from the environment |
| `setup/docker-dns.sh` | points Docker at the router's DNS, recreates Dokku apps                             |
| `setup/install/`      | partitioning, LUKS, chroot, debloat and tuning, plus `GUIDE.md`                     |

Dokku, the deployed apps and the running history of the box are not here; those live in a
private homelab repo that consumes this one.

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
- **One owner per path.** Shared files first, platform overlay second, so a `$HOME` path can never be claimed by two places at once.
- **Preferences are code, application state is not.** `defaults write` lines live in the repo; whole-domain plists are imported; the VS Code files are symlinked; anything that is regenerated (a `Rectangle` export, a `brew bundle dump`) is captured deliberately.
- **Values are not code.** Addresses, domains and account names come from the gitignored host file, so the scripts can be public and still be correct on my machines.
- **Nothing needs sudo implicitly.** Package installs and `bootstrap` run as your user; the sudo-only preferences are behind `--system`, the Ubuntu system scripts are run by hand, and `repair.sh` is manual.
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
