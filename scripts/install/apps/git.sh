#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Asked every time: a work machine commits under another name and email. The
# defaults are what git has already, else the personal ones.
GIT_DEFAULT_NAME="Irrisorr"
GIT_DEFAULT_EMAIL="zakharkevichg@gmail.com"

# Menu guard: git
# About: Asks for your git name and email (this machine's current ones, else the personal ones, are prefilled).
configure_git() {
  local name email
  print_styled_message "Configure Git"
  name=$(git config --global user.name || echo "$GIT_DEFAULT_NAME")
  email=$(git config --global user.email || echo "$GIT_DEFAULT_EMAIL")
  name=$(gum input --header "Git user name" --value "$name" </dev/tty) || return 1
  email=$(gum input --header "Git email" --value "$email" </dev/tty) || return 1
  [ -n "$name" ] && [ -n "$email" ] || { print_error_message "Name and email can't be empty"; return 2; }
  git config --global user.name "$name" && git config --global user.email "$email" || return 2
  print_success_message "git commits as $name <$email>"
}
