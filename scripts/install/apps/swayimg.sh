#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: swayimg
configure_swayimg() {
  execute_command "Configure swayimg" "create_symlink $HOME/Dotfiles/swayimg $HOME/.config/swayimg"
}
