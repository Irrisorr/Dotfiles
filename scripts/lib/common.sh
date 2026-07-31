#!/bin/bash
#
# Shared constants and includes for all Dotfiles scripts.
# Source this at the top of any script:
#   . "$HOME/Dotfiles/scripts/lib/common.sh"
#
# After sourcing you get the path constants below plus every helper from
# lib/gum.sh and lib/helpers.sh (print_*, confirm_action, create_symlink,
# execute_command, the menu parsers, the package engine, etc).

# Source once — many files source this and the menus source several of them,
# so guard against redundant re-sourcing within one shell.
[ -n "$_DOTFILES_COMMON" ] && return
_DOTFILES_COMMON=1

export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Dotfiles}"
export PRIVATE_DIR="${PRIVATE_DIR:-$HOME/Dotfiles-private}"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"
export LIB_DIR="$SCRIPTS_DIR/lib"
export INSTALL_DIR="$SCRIPTS_DIR/install"
export SYSTEM_DIR="$INSTALL_DIR/system"
export APPS_DIR="$INSTALL_DIR/apps"
export FUNCTIONS_DIR="$SCRIPTS_DIR/functions"
export CONFIG_DIR="$HOME/.config"

. "$LIB_DIR/gum.sh"
. "$LIB_DIR/helpers.sh"
