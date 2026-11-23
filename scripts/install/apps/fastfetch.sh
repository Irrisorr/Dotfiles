#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fastfetch
# About: Links the fastfetch config (system info at terminal start).
configure_fastfetch() {
  execute_command "Configure fastfetch" "create_symlink $HOME/Dotfiles/fastfetch $HOME/.config/fastfetch"
}
