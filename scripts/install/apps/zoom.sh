#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zoom
configure_zoom() {
  print_styled_message "Configuring Zoom"
  if ! confirm_action "configure Zoom for Wayland"; then
    return 1
  fi

  if [ -f $HOME/.config/zoomus.conf ]; then
    if grep -q "enableWaylandShare" $HOME/.config/zoomus.conf; then
      sed -i 's/enableWaylandShare=.*/enableWaylandShare=true/' $HOME/.config/zoomus.conf
    else
      echo "enableWaylandShare=true" >>$HOME/.config/zoomus.conf
    fi
  else
    echo "enableWaylandShare=true" >$HOME/.config/zoomus.conf
  fi
  print_success_message "Zoom configured for Wayland"
}
