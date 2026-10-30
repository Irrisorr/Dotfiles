#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: clipse
configure_clipse() {
  execute_command "Configure clipse" "create_symlink $HOME/Dotfiles/clipse/config.json $HOME/.config/clipse/config.json"
}
