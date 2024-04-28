# Sync various settings automatically to write to this directory

# code --list-extensions | xargs -L 1 echo code --install-extension

from invoke import task
from pathlib import Path
from termcolor import cprint
import shutil

APP_SUPPORT = Path.home() / Path('Library/Application Support/')
VS_CODE_APPLICATION = Path.home() / Path('Library/Application Support/Code/User')
INIT_DIR = Path.cwd() / 'init'


"""
- Copy rectangle settings
- remove karabiner and spectacle
- ?
"""


@task
def brew(c):
    installed = c.run('brew list --cask -1')
    casks = installed.stdout.replace('\r', '').split('\n')

    formula = c.run('brew leaves')
    formulas = formula.stdout.replace('\r', '').split('\n')

    brew_path = Path.cwd() / 'brew.sh'
    with brew_path.open(mode='a+') as f:
        f.seek(0)
        contents = f.read()
        for cask in casks:
            if cask not in contents:
                f.write(f'brew install --cask {cask}\n')
                print(f'Added {cask}')

        for formula in formulas:
            if formula not in contents:
                f.write(f'brew install {formula}\n')
                print(f'Added {formula}')


@task
def backup_vscode(c):
    """
    Copy settings and extensions from VS Code to dotfiles
    """
    result = c.run('code --list-extensions | xargs -L 1 echo code --install-extension')
    with (Path.cwd() / 'init' / 'vscode' / 'vscode.sh').open(mode='w') as f:
        f.write(result.stdout)

    src_keybindings = VS_CODE_APPLICATION / 'keybindings.json'
    dst_keybindings = INIT_DIR / 'vscode' / 'keybindings.json'
    shutil.copyfile(src_keybindings, dst_keybindings)

    src_settings = VS_CODE_APPLICATION / 'settings.json'
    dst_settings = INIT_DIR / 'vscode' / 'settings.json'
    shutil.copyfile(src_settings, dst_settings)

    shutil.rmtree(INIT_DIR / 'vscode' / 'snippets')
    shutil.copytree(VS_CODE_APPLICATION / 'snippets', INIT_DIR / 'snippets')


@task
def uninstall_vscode_extensions(c):
    """
    Uninstall all vscode extensions
    """
    result = c.run('code --list-extensions | xargs -L 1 echo code --uninstall-extension')
    extensions = result.stdout.split('\n')
    for extension in extensions:
        c.run(extension)


@task
def install_vscode(c):
    """
    Install the VS code settings to the system from dotfiles

    NOTE: Will fail if vs code hasn't been run before.
    """
    cprint('Installing VS code extensions', 'green')
    vscode_dir = INIT_DIR / 'vscode'
    keybindings = vscode_dir / 'keybindings.json'
    settings = vscode_dir / 'settings.json'

    settings_dest = VS_CODE_APPLICATION / 'settings.json'
    keybindings_dest = VS_CODE_APPLICATION / 'keybindings.json'

    c.run('cp {} {}'.format(keybindings, keybindings_dest))
    c.run('cp {} {}'.format(settings, settings_dest))
    # TODO copy all snippets from the snippets folder.

    # install the vscode extensions
    c.run('source {}/vscode.sh'.format(vscode_dir))


@task
def spectacle(c, backup=False):
    """
    NOTE: Will fail if spectacle hasn't been run before.
    """
    shortcuts_dest = APP_SUPPORT / 'Spectacle' / 'Shortcuts.json'
    shortcuts_src = INIT_DIR / 'spectacle.json'

    if backup:
        c.run('cp {} {}'.format(shortcuts_dest, shortcuts_src))
        return

    cprint('Set up settings for spectacle', 'green')
    c.run('cp {} {}'.format(shortcuts_src, shortcuts_dest))


@task
def iterm2(c, backup=False):
    """Install or backup preferences for iterm2"""

    # use plutil to convert to xml for better readability of changes
    # plutil -convert xml1 ExampleBinary.plist
    # plutil -convert binary1 Example.plist
    dest = Path.home() / Path('Library/Preferences/com.googlecode.iterm2.plist')
    src = INIT_DIR / 'com.googlecode.iterm2.plist'
    if backup:
        c.run(f'cp {dest} {src}')
        return

    cprint('Set up settings for iterm2', 'green')
    # TODO use shutil instead.
    c.run(f'cp {src} {dest}')
    c.run('defaults read com.googlecode.iterm2')


@task
def karabiner(c, backup=False):
    src = INIT_DIR / 'karabiner.json'
    dest = '~/.config/karabiner'

    if backup:
        c.run(f'cp {dest}/karabiner.json {src}')
        return
    cprint('Set up settings for karabiner', 'green')
    c.run(f'mkdir -p {dest} && cp {src} {dest}/karabiner.json')


@task
def keyboard(c):
    """Copy keyboard layout to the correct place"""
    src = INIT_DIR / 'Swedish-Svorak.keylayout'
    dest = '~/Library/Keyboard\ Layouts/Swedish-Svorak.keylayout'
    cprint('Install keyboard layout', 'green')
    c.run(f'cp {src} {dest}')


@task
def setup(c):
    """Copy all preferences to the correct location"""
    install_vscode(c)
    iterm2(c)
    karabiner(c)
    keyboard(c)
    spectacle(c)


@task
def backup(c):
    """Backup all files that has changed at some point"""
    backup_vscode(c)
    iterm2(c, backup=True)
    karabiner(c, backup=True)
    spectacle(c, backup=True)


@task
def bootstrap(c):
    """Moves the .zsh profile and other config stuff to HOME"""
    user_input = input('This may overwrite existing files in your home directory. Are you sure? (y/n) ')
    if user_input != 'y':
        return

    c.run("""
        rsync --exclude ".git/" \
        --exclude ".DS_Store" \
        --exclude "bootstrap.sh" \
        --exclude "README.md" \
        --exclude "LICENSE-MIT.txt" \
        --exclude "venv" \
        --exclude "brew.sh" \
        --exclude "setup.sh \
        --exclude "init" \
        --exclude "tasks.py \
        --exclude "requirements.txt" \
        -avh --no-perms . ~;
    """)

    cprint("Copying dotfiles to HOME", "green")
    c.run("source ~/.zprofile;", shell="/bin/zsh")

    cprint("MacOS specific settings", "green")
    c.run("source ~/.macos;", shell="/bin/zsh")
