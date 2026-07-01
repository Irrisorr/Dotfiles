#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fish
configure_fish() {
  execute_command "Configure fish" "mkdir -p $HOME/.config/fish && create_symlink $HOME/Dotfiles/fish $HOME/.config/fish && chsh -s /bin/fish"
}
