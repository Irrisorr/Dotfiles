#!/bin/bash
#
# Restart the xdg-desktop-portal stack for a Hyprland session.
# Thin shim over scripts/wrappers/xdg-portals.sh, which resolves the portal
# binaries per distro (Arch: /usr/lib, Debian: /usr/libexec).

exec "$HOME/Dotfiles/scripts/wrappers/xdg-portals.sh" \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal
