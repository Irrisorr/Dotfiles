#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Same commands on both distros — pkg_sync / pkg_upgrade pick yay, pacman or apt
# (and flatpak) from lib/distro.sh.
update_system() {
  pkg_sync
}

upgrade_system() {
  pkg_upgrade -i
}

# Submenu opened from the asd menu. A menu entry whose function calls menu()
# again becomes a nested menu with its own back button — see lib/helpers.sh.
package_commands() {
  menu "⬅️ Back" \
    "System update|update_system" \
    "System upgrade|upgrade_system"
}

# Dispatcher: run the named function when executed directly (fish wrappers pass
# the function name, e.g. `bash system_packages.sh update_system`).
[ "${BASH_SOURCE[0]}" = "$0" ] && "$@"
