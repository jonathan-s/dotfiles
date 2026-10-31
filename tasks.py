# Sync various settings automatically to write to this directory

# code --list-extensions | xargs -L 1 echo code --install-extension

from invoke import task
from pathlib import Path
from termcolor import cprint
import plistlib
import shutil

VS_CODE_APPLICATION = Path.home() / Path('Library/Application Support/Code/User')
INIT_DIR = Path.cwd() / 'macos'

RECTANGLE_PREFS = 'com.knollsoft.Rectangle'
# Window geometry, navigation state and Sparkle update bookkeeping are
# machine state, not settings, so they stay out of the repo.
RECTANGLE_SKIP_PREFIXES = ('NS', 'SU')
RECTANGLE_SKIP_KEYS = {'internalTilingNotified', 'lastVersion'}



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
    with (INIT_DIR / 'vscode' / 'vscode.sh').open(mode='w') as f:
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
def keyboard(c):
    """Copy keyboard layout to the correct place"""
    src = INIT_DIR / 'Swedish-Svorak.keylayout'
    dest = '~/Library/Keyboard\ Layouts/Swedish-Svorak.keylayout'
    cprint('Install keyboard layout', 'green')
    c.run(f'cp {src} {dest}')


@task
def rectangle(c, backup=False):
    """Install or backup the Rectangle window manager settings

    Imported shortcuts only show up after Rectangle is restarted.
    """
    src = INIT_DIR / 'rectangle.plist'

    if backup:
        exported = c.run(f'defaults export {RECTANGLE_PREFS} -', hide=True)
        data = plistlib.loads(exported.stdout.encode())
        for key in list(data):
            if key.startswith(RECTANGLE_SKIP_PREFIXES) or key in RECTANGLE_SKIP_KEYS:
                del data[key]
        with src.open('wb') as f:
            plistlib.dump(data, f, sort_keys=True)
        return

    cprint('Set up settings for rectangle', 'green')
    c.run(f'defaults import {RECTANGLE_PREFS} {src}')


@task
def setup(c):
    """Copy all preferences to the correct location"""
    install_vscode(c)
    keyboard(c)
    rectangle(c)


@task
def backup(c):
    """Backup all files that has changed at some point"""
    backup_vscode(c)
    rectangle(c, backup=True)
