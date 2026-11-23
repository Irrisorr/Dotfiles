#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: kitty
# About: Links the kitty config.
configure_kitty() {
  execute_command "Configure kitty" "create_symlink $HOME/Dotfiles/kitty $HOME/.config/kitty"
}
