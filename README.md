# Jonathan's dotfiles

![Screenshot of my shell prompt](https://i.imgur.com/EkEtphC.png)

This repo is indebted to https://github.com/mathiasbynens/dotfiles, as it is a fork from that repo.

This repo has added the following extra things.

- Support for zsh instead of bash.
- `home/` mirrors `$HOME` and is symlinked into place, so there is only one copy of every config.
- `./install` sets up a new machine; `Brewfile` lists the packages.
- Svorak! (swedish dvorak)

## Installation

**Warning:** If you want to give these dotfiles a try, you should first fork this repository, review the code, and remove things you don’t want or need. Don’t blindly use my settings unless you know what that entails. Use at your own risk!

### What is in here

| Path         | What it does                                                            |
| ------------ | ----------------------------------------------------------------------- |
| `bootstrap`  | symlinks `home/` into `$HOME` and prunes links whose file left the repo |
| `install`    | cold-start orchestrator: packages, tools, links, login shell            |
| `Brewfile`   | `brew bundle` manifest of formulae and casks                            |
| `home/`      | everything that belongs in `$HOME`                                      |
| `macos/`     | macOS preferences and app settings, applied by `bootstrap` on Macs      |
| `.githooks/` | pre-commit guard against committing credentials                         |

`./bootstrap --dry-run` shows what it would change, `--verify` reports broken links, and
`--report` answers "is the repo in sync?" in one command: links, files shadowing a tracked
config, uncommitted repo changes, and macOS defaults drift. `./macos/defaults.sh --check`
reports just the macOS preferences.

### Installing a new machine

Install [Homebrew](https://brew.sh/) first, then:

```bash
git clone https://github.com/jonathan-s/dotfiles.git && cd dotfiles
./install
```

`./install` runs five stages (preflight, packages, tools, links, shell) and is safe to re-run.
When you only want to know whether the machine still matches this repo:

```bash
./install --check          # changes nothing, exits non-zero on drift
./install --only links     # run a single stage
```

### Updating

`./bootstrap` is the fast path — it only relinks the dotfiles:

```bash
git pull && ./bootstrap
```

It also points `core.hooksPath` at `.githooks/`, which holds a pre-commit hook that refuses
to commit anything resembling a token or a private key.

### Packages

Packages are declared in `Brewfile`. After installing something new, capture it:

```bash
brew bundle dump --file=Brewfile --force
```

`./install --check` reports packages that are in the `Brewfile` but missing from the machine.

### Local overrides

`~/.path` is sourced with the other dotfiles, so extra `$PATH` entries can live there without
touching the repo:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Feedback

Suggestions/improvements
[welcome](https://github.com/jonathan-s/dotfiles/issues)!


## Big thanks to the original Author

| [![twitter/mathias](http://gravatar.com/avatar/24e08a9ea84deb17ae121074d0f17125?s=70)](http://twitter.com/mathias "Follow @mathias on Twitter") |
| ----------------------------------------------------------------------------------------------------------------------------------------------- |
| [Mathias Bynens](https://mathiasbynens.be/)                                                                                                     |

## Thanks to…

* @ptb and [his _macOS Setup_ repository](https://github.com/ptb/mac-setup)
* [Ben Alman](http://benalman.com/) and his [dotfiles repository](https://github.com/cowboy/dotfiles)
* [Cătălin Mariș](https://github.com/alrra) and his [dotfiles repository](https://github.com/alrra/dotfiles)
* [Gianni Chiappetta](https://butt.zone/) for sharing his [amazing collection of dotfiles](https://github.com/gf3/dotfiles)
* [Jan Moesen](http://jan.moesen.nu/) and his [ancient `.bash_profile`](https://gist.github.com/1156154) + [shiny _tilde_ repository](https://github.com/janmoesen/tilde)
* Lauri ‘Lri’ Ranta for sharing [loads of hidden preferences](https://web.archive.org/web/20161104144204/http://osxnotes.net/defaults.html)
* [Matijs Brinkhuis](https://matijs.brinkhu.is/) and his [dotfiles repository](https://github.com/matijs/dotfiles)
* [Nicolas Gallagher](http://nicolasgallagher.com/) and his [dotfiles repository](https://github.com/necolas/dotfiles)
* [Sindre Sorhus](https://sindresorhus.com/)
* [Tom Ryder](https://sanctum.geek.nz/) and his [dotfiles repository](https://sanctum.geek.nz/cgit/dotfiles.git/about)
* [Kevin Suttle](http://kevinsuttle.com/) and his [dotfiles repository](https://github.com/kevinSuttle/dotfiles) and [macOS-Defaults project](https://github.com/kevinSuttle/macOS-Defaults), which aims to provide better documentation for [`~/.macos`](https://mths.be/macos)
* [Haralan Dobrev](https://hkdobrev.com/)
* Anyone who [contributed a patch](https://github.com/mathiasbynens/dotfiles/contributors) or [made a helpful suggestion](https://github.com/mathiasbynens/dotfiles/issues)
