#!/bin/bash
#
# Restart the xdg-desktop-portal stack for the current session.
# Portal paths differ per distro, so they go through lib/paths.sh instead of
# being hardcoded into a shared config.
#
#   xdg-portals.sh <portal-name>...
#
# Hyprland only — under niri the portals come up as systemd user units.
# Sources lib/paths.sh, NOT lib/common.sh — see polkit-agent.sh.

. "$HOME/Dotfiles/scripts/lib/paths.sh"

portals=("$@")
if [ ${#portals[@]} -eq 0 ]; then
  portals=(xdg-desktop-portal-hyprland xdg-desktop-portal)
fi

sleep 1

# Kill stale backends from a previous session.
for p in xdg-desktop-portal-hyprland xdg-desktop-portal-gnome \
         xdg-desktop-portal-kde xdg-desktop-portal-lxqt \
         xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal; do
  killall "$p" 2>/dev/null
done
sleep 1

# xdg-desktop-portal comes up last: it queries the backends.
for p in "${portals[@]}"; do
  bin=$(find_portal_binary "$p")
  if [ -z "$bin" ]; then
    echo ":: Portal not installed, skipping: $p" >&2
    continue
  fi
  echo ":: Starting $bin"
  "$bin" &
  sleep 2
done
