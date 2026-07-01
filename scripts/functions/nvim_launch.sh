#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Nvim launch
nvim_launch() {
  niri msg action set-column-width "100%"
  niri msg action move-window-to-workspace ide
  nvim "$@"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && nvim_launch "$@"
