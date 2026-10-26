#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: spicetify
configure_spicetify() {
  # The repo has no spicetify config yet — linking would leave a dead symlink.
  if [ ! -d "$DOTFILES_DIR/spicetify" ]; then
    print_error_message "No spicetify config in $DOTFILES_DIR/spicetify — nothing to link"
    return 2
  fi
  execute_command "Configure spicetify" "create_symlink $HOME/Dotfiles/spicetify $HOME/.config/spicetify"
}
