#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: spicetify-cli
configure_spicetify() {
  execute_command "Configure spicetify" "mkdir -p $HOME/.config/spicetify && create_symlink $HOME/Dotfiles/spicetify $HOME/.config/spicetify"
}
