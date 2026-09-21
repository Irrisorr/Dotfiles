#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Rain animation
terminal_rain() {
  terminal-rain "$@"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && terminal_rain "$@"
