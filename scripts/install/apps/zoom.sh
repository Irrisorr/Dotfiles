#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zoom
# A flatpak install (older Ubuntu setups) reads its config from its own XDG dir,
# not ~/.config; the native package (both distros now) wins when both are there.
configure_zoom() {
  print_styled_message "Configuring Zoom"
  if ! confirm_step "configure Zoom for Wayland"; then
    return 1
  fi

  local conf="$HOME/.config/zoomus.conf"
  if ! pkg_installed zoom && command -v flatpak &>/dev/null && flatpak info us.zoom.Zoom &>/dev/null; then
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
