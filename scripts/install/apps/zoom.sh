#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zoom
# The flatpak (Ubuntu) reads its config from its own XDG dir, not ~/.config.
configure_zoom() {
  print_styled_message "Configuring Zoom"
  if ! confirm_action "configure Zoom for Wayland"; then
    return 1
  fi

  local conf="$HOME/.config/zoomus.conf"
  if command -v flatpak &>/dev/null && flatpak info us.zoom.Zoom &>/dev/null; then
    conf="$HOME/.var/app/us.zoom.Zoom/config/zoomus.conf"
  fi
  mkdir -p "$(dirname "$conf")"

  if grep -qs "enableWaylandShare" "$conf"; then
    sed -i 's/enableWaylandShare=.*/enableWaylandShare=true/' "$conf"
  else
    echo "enableWaylandShare=true" >> "$conf"
  fi
  check_success "Zoom configured for Wayland ($conf)"
}
