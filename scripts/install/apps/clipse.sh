#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: clipse
configure_clipse() {
  execute_command "Configure clipse" "mkdir -p $HOME/.config/clipse && create_symlink $HOME/Dotfiles/clipse/config.json $HOME/.config/clipse/"
}
