#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: wlogout
configure_wlogout() {
  execute_command "Configure wlogout" "create_symlink $HOME/Dotfiles/wlogout $HOME/.config/wlogout"
}
