#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: niri
configure_niri() {
  print_styled_message "Configuring niri and apps/plugins for it"

  execute_command "Configure niri directory" "create_symlink $HOME/Dotfiles/niri $HOME/.config/niri"

  execute_command "Configure dms-shell (panel-bar)" "mkdir -p $HOME/.config/DankMaterialShell && create_symlink $HOME/Dotfiles/DankMaterialShell $HOME/.config/DankMaterialShell"

  if command -v hyprlock &>/dev/null; then
    execute_command "Configure hyprlock" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprlock.conf $HOME/.config/hypr/hyprlock.conf"
  fi
}
