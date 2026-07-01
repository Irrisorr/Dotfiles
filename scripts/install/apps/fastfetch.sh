#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fastfetch
configure_fastfetch() {
  execute_command "Configure fastfetch" "mkdir -p $HOME/.config/fastfetch && create_symlink $HOME/Dotfiles/fastfetch $HOME/.config/fastfetch"
}
