#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: wofi
# About: Links the wofi config.
configure_wofi() {
  execute_command "Configure Wofi" "create_symlink $HOME/Dotfiles/wofi $HOME/.config/wofi"
}
