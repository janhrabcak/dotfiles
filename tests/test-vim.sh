#!/bin/bash
echo "Installing Vim plugins..."
vim +PlugInstall +qall!
echo "Vim exited."
pgrep -f -l "vim|go" || true
