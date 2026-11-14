#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: thunar
configure_thunar() {
  execute_command "Configure Thunar" "mkdir -p $HOME/.config/Thunar && create_symlink $HOME/Dotfiles/thunar/uca.xml $HOME/.config/Thunar/uca.xml"
}
