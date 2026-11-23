#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: rofi
# About: Links the rofi config.
configure_rofi() {
  execute_command "Configure Rofi" "create_symlink $HOME/Dotfiles/rofi $HOME/.config/rofi"
}
