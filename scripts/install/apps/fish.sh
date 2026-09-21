#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fish
configure_fish() {
  # ensure_login_shell registers fish in /etc/shells before chsh — Ubuntu ships
  # fish at /usr/bin/fish and chsh rejects any shell missing from that file.
  execute_command "Configure fish" "create_symlink $HOME/Dotfiles/fish $HOME/.config/fish && ensure_login_shell \"\$(fish_bin)\""
}
