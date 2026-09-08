#!/bin/bash
echo "Installing Vim plugins..."
vim +PlugInstall +qall!
echo "Vim exited."
ps aux | grep -v grep | grep -E "vim|go" || true
