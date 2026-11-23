#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: thunar
# About: Links Thunar's custom actions (right-click menu).
configure_thunar() {
  execute_command "Configure Thunar" "mkdir -p $HOME/.config/Thunar && create_symlink $HOME/Dotfiles/thunar/uca.xml $HOME/.config/Thunar/uca.xml"
}
