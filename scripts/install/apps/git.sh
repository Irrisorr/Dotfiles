#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: git
configure_git() {
  execute_command "Configure Git" "git config --global user.name Irrisorr && git config --global user.email zakharkevichg@gmail.com"
}
