# Jonathan's dotfiles

![Screenshot of my shell prompt](https://i.imgur.com/EkEtphC.png)

This repo is indebted to https://github.com/mathiasbynens/dotfiles, as it is a fork from that repo.

This repo has added the following extra things.
- Python scripting to make it easier to add extra stuff if you want to avoid bash.
- Support for .zsh instead of bash.
- Svorak! (swedish dvorak)

## Installation

**Warning:** If you want to give these dotfiles a try, you should first fork this repository, review the code, and remove things you don’t want or need. Don’t blindly use my settings unless you know what that entails. Use at your own risk!

### Installation components

The following components exist

- ./brew.sh - Installs all brew packages. Make sure that you've got brew installed first!
- ./setup.sh - Sets up python environment etc so that you can run invoke.
- ./bootstrap - Links everything in `home/` into `$HOME`. Use `./bootstrap --dry-run` first, `--verify` afterwards.
- ./macos/defaults.sh - Run this if it's on a clean install.

Once you've run setup.sh you can also run the python invoke commands.

- inv setup - Copy all application specific configuration files to correct place
- inv backup - will backup the application configurations files to dotfiles.


### Using Git and the bootstrap script

You can clone the repository wherever you want. (I like to keep it in `~/projects/dotfiles`.) The bootstrapper script links the files from `home/` into your home folder.

```bash
git clone https://github.com/jonathan-s/dotfiles.git && cd dotfiles && ./bootstrap
```

To update, `cd` into your local `dotfiles` repository and then:

```bash
git pull && ./bootstrap
```

`./bootstrap` also points `core.hooksPath` at `.githooks/`, which holds a
pre-commit hook that refuses to commit anything resembling a token or a
private key.

### Specify the `$PATH`

If `~/.path` exists, it will be sourced along with the other files, before any feature testing (such as [detecting which version of `ls` is being used](https://github.com/mathiasbynens/dotfiles/blob/aff769fd75225d8f2e481185a71d5e05b76002dc/.aliases#L21-L26)) takes place.

Here’s an example `~/.path` file that adds `/usr/local/bin` to the `$PATH`:

```bash
export PATH="/usr/local/bin:$PATH"
```

### Install Homebrew formulae

When setting up a new Mac, you may want to install some common [Homebrew](https://brew.sh/) formulae (after installing Homebrew, of course):

```bash
./brew.sh
```

Some of the functionality of these dotfiles depends on formulae installed by `brew.sh`. If you don’t plan to run `brew.sh`, you should look carefully through the script and manually install any particularly important ones.

## Feedback

Suggestions/improvements
[welcome](https://github.com/jonathan-s/dotfiles/issues)!


## Big thanks to the original Author

| [![twitter/mathias](http://gravatar.com/avatar/24e08a9ea84deb17ae121074d0f17125?s=70)](http://twitter.com/mathias "Follow @mathias on Twitter") |
|---|
| [Mathias Bynens](https://mathiasbynens.be/) |

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
