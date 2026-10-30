#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: distro:debian
# Arch gets these apps from the AUR, so flatpak is only worth setting up on
# Debian-family systems.
enable_flatpak() {
  execute_command "Install flatpak and add the Flathub remote" "ensure_flatpak"
}
