#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: niri
#
# One action per entry, so the fzf config menu can list them under the step and
# run only the ticked ones (run_substeps in lib/helpers.sh).
configure_niri_steps=(
  "niri config|_niri_link_config"
  "Dux shell config (panel bar)|_niri_link_dux"
  "hyprlock config|_niri_link_hyprlock|hyprlock"
  "Disable globally enabled DMS units|_disable_global_dms_units|test:_global_dms_units"
)

configure_niri() {
  print_styled_message "Configuring niri and apps/plugins for it"
  run_substeps "${configure_niri_steps[@]}"
}

_niri_link_config() {
  execute_command "Configure niri directory" "create_symlink $HOME/Dotfiles/niri $HOME/.config/niri"
}

_niri_link_dux() {
  execute_command "Configure Dux shell (panel-bar)" "create_symlink $HOME/Dotfiles/dms $HOME/.config/dms"
}

_niri_link_hyprlock() {
  execute_command "Configure hyprlock" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprlock.conf $HOME/.config/hypr/hyprlock.conf"
}


# Prints the DMS user units enabled globally; fails when there are none.
_global_dms_units() {
  local unit found=1
  for unit in dms.service dsearch.service; do
    systemctl --global is-enabled "$unit" &>/dev/null && { echo "$unit"; found=0; }
  done
  return $found
}


# niri's autostart runs `dms run`. Ubuntu's dms package also enables its user
# units globally (graphical-session.target), so DMS would start in every
# graphical session — the GDM login screen included — and twice under niri.
# Arch ships them disabled; this brings Ubuntu in line. No-op when none is on.
_disable_global_dms_units() {
  local units
  units=$(_global_dms_units) || return 0
  units=${units//$'\n'/ }
  execute_command "Disable globally enabled $units (niri starts DMS itself)" \
    "sudo systemctl --global disable $units"
}
