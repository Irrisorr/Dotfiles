#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Puts back the fonts chosen with `fonts` (scripts/functions/fonts.sh): links
# fontconfig/ and writes GTK and VS Code, which live outside the dotfiles.
# Qt, DMS, Zen and kitty read theirs from the dotfiles already.

# Packages for the families the dotfiles name; a family missing here is
# reported instead.
declare -A FONT_PACKAGES=(["JetBrainsMono Nerd Font"]=ttf-jetbrains-mono-nerd)

# The chosen families must be installed: otherwise every place names a font
# fontconfig quietly replaces (DejaVu, Noto).
_fonts_installed() {
  local fam pkg
  local -a missing=() pkgs=()
  . "$HOME/Dotfiles/scripts/functions/fonts.sh"
  for fam in "$(ft_ui)" "$(ft_mono)"; do
    [ -n "$(fc-list ":family=$fam" family)" ] && continue
    [[ " ${missing[*]} " == *" $fam "* ]] || missing+=("$fam")
  done
  [ ${#missing[@]} -eq 0 ] && return 0
  for fam in "${missing[@]}"; do
    pkg=${FONT_PACKAGES[$fam]}
    if [ -n "$pkg" ]; then
      pkgs+=("$pkg")
    else
      print_error_message "Font \"$fam\" isn't installed and has no package here: install it, or pick another with \`fonts\`"
      return 2
    fi
  done
  echo ":: Not installed: ${missing[*]}"
  install_packages "${pkgs[@]}" || return 2
}

# About: Restores the saved fonts in GTK, Qt, the Dux shell and VS Code, installing JetBrains Mono Nerd first if it's missing.
configure_fonts() {
  _fonts_installed || return
  execute_command "Restore fonts" ". $HOME/Dotfiles/scripts/functions/fonts.sh && fonts_restore"
}
