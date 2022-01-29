#!/bin/zsh

# Make sure that we have a sane python version as global
pyenv install 3.10.1
pyenv global 3.10.1

# We need to use invoke, so install that.
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Setup all preferences
inv setup
