#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: wlogout
# About: Links the wlogout (logout menu) config.
configure_wlogout() {
  execute_command "Configure wlogout" "create_symlink $HOME/Dotfiles/wlogout $HOME/.config/wlogout"
}
