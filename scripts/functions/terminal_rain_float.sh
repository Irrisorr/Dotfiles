#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Rain animation in mini floating window
terminal_rain_float() {
  niri msg action set-window-height 300
  niri msg action set-window-width 400
  niri msg action toggle-window-floating
  terminal-rain "$@"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && terminal_rain_float "$@"
