#!/bin/bash
#
# Start a polkit authentication agent, wherever this distro keeps it.
# Called from the WM autostart configs, which are shared between machines and
# so cannot contain a distro-specific absolute path.
#
#   polkit-agent.sh [gnome|mate]     (default: gnome, falling back to mate)
#
# Sources lib/paths.sh, NOT lib/common.sh — common.sh runs the gum bootstrap,
# which must never happen during a compositor's startup.

. "$HOME/Dotfiles/scripts/lib/paths.sh"

agent=$(find_polkit_agent "${1:-gnome}") || agent=$(find_polkit_agent mate)

if [ -z "$agent" ]; then
  echo ":: No polkit authentication agent found, skipping." >&2
  exit 0
fi

exec "$agent"
