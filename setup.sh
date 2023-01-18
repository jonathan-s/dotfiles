#!/bin/zsh

# install brew.

echo "Install brew, and brew packages? (y/n)"
read INSTALL_BREW

if [[ $INSTALL_BREW == "y" ]]
then
  source brew.sh
fi

# Make sure that we have a sane python version as global
pyenv install 3.10.1
pyenv global 3.10.1

# We need to use invoke, so install that.
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install oh-my-zsh to be able to use plugins etc.
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Setup all preferences
inv bootstrap
inv setup
