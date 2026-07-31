#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

update_system() {
  yay -Sy "$@"
}

upgrade_system() {
  yay -Syu "$@"
}

# Submenu opened from the asd menu. A menu entry whose function calls menu()
# again becomes a nested menu with its own back button — see lib/helpers.sh.
yay_commands() {
  menu "⬅️ Back" \
    "System update|update_system" \
    "System upgrade|upgrade_system"
}

# Dispatcher: run the named function when executed directly (fish wrappers pass
# the function name, e.g. `bash yay_pacman.sh update_system`).
[ "${BASH_SOURCE[0]}" = "$0" ] && "$@"
