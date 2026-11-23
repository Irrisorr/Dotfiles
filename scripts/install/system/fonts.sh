#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Puts back the fonts chosen with `fonts` (scripts/functions/fonts.sh): links
# fontconfig/ and writes GTK and VS Code, which live outside the dotfiles.
# Qt, DMS, Zen and kitty read theirs from the dotfiles already.

# About: Restores the saved fonts in GTK, Qt, the Dux shell and VS Code.
configure_fonts() {
  execute_command "Restore fonts" ". $HOME/Dotfiles/scripts/functions/fonts.sh && fonts_restore"
}
