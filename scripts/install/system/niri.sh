#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: niri
configure_niri() {
  print_styled_message "Configuring niri and apps/plugins for it"

  execute_command "Configure niri directory" "create_symlink $HOME/Dotfiles/niri $HOME/.config/niri"

  execute_command "Configure dms-shell (panel-bar)" "create_symlink $HOME/Dotfiles/DankMaterialShell $HOME/.config/DankMaterialShell"

  _disable_global_dms_units

  if command -v hyprlock &>/dev/null; then
    execute_command "Configure hyprlock" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprlock.conf $HOME/.config/hypr/hyprlock.conf"
  fi
}


# niri's autostart runs `dms run`. Ubuntu's dms package also enables its user
# units globally (graphical-session.target), so DMS would start in every
# graphical session — the GDM login screen included — and twice under niri.
# Arch ships them disabled; this brings Ubuntu in line. No-op when none is on.
_disable_global_dms_units() {
  local unit enabled=()
  for unit in dms.service dsearch.service; do
    systemctl --global is-enabled "$unit" &>/dev/null && enabled+=("$unit")
  done
  [ ${#enabled[@]} -eq 0 ] && return 0

  execute_command "Disable globally enabled ${enabled[*]} (niri starts DMS itself)" \
    "sudo systemctl --global disable ${enabled[*]}"
}
