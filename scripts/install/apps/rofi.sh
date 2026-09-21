#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: rofi
configure_rofi() {
  execute_command "Configure Rofi" "mkdir -p $HOME/.config/rofi && create_symlink $HOME/Dotfiles/rofi $HOME/.config/rofi"
}
