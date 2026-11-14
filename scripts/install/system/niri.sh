#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: niri
#
# One action per entry, so the fzf config menu can list them under the step and
# run only the ticked ones (run_substeps in lib/helpers.sh).
configure_niri_steps=(
  "niri config|_niri_link_config"
  "Dux shell config (panel bar)|_niri_link_dux"
  "Dux shell plugins|_niri_restore_dux_plugins|dms"
  "Add user to the input group (Bongo Cat)|_niri_input_group|test:_niri_not_in_input_group"
  "Dux greeter (login screen, replaces SDDM/GDM)|_niri_dux_greeter|dms-greeter"
  "Dux calendar config|_niri_link_dux_calendar|dcal"
  "Dux files config (default file manager, open/save dialogs)|_niri_dux_files|dfiles"
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

# Plugin code isn't tracked (dms/plugins/ is ignored): the lockfile pins each
# plugin's repo and commit, restore clones them. Their settings are in the tracked
# dms/plugin_settings.json.
_niri_restore_dux_plugins() {
  execute_command "Restore Dux shell plugins" "dms plugins restore $HOME/.config/dms/plugins.lock.json"
}

_niri_not_in_input_group() {
  ! id -nG "$USER" | grep -qw input
}

# Bongo Cat reads /dev/input/event* through evtest / libinput. Note: the input
# group lets any of the user's processes read every keystroke. Needs a re-login.
_niri_input_group() {
  execute_command "Add $USER to the input group (re-login to apply)" "sudo usermod -aG input $USER"
}

# Installs greetd, points it at dms-greeter, disables the old display manager,
# then syncs: greeter group, ACLs on ~ and the DMS config, links to settings,
# wallpaper and colors, fingerprint PAM if greeterEnableFprint is on.
# It escalates by itself and refuses to run under sudo.
_niri_dux_greeter() {
  execute_command "Make the Dux greeter the login screen (re-login, then: dms-greeter status; back: dms-greeter uninstall)" \
    "dms-greeter install --yes"
}

# Only the UI settings; accounts live in ~/.local/share/dankcal and the keyring,
# so add them again on a new machine (dcal account add google).
_niri_link_dux_calendar() {
  execute_command "Configure Dux calendar" "create_symlink $HOME/Dotfiles/dankcal $HOME/.config/dankcal"
}

# The portal file is the one `dfiles portal install` writes: only the
# FileChooser line, so dfiles serves open/save dialogs with gnome/gtk as fallback.
# xdg-desktop-portal reads it at startup, hence the restart.
_niri_dux_files() {
  execute_command "Configure Dux files" \
    "create_symlink $HOME/Dotfiles/dfiles $HOME/.config/dfiles \
     && create_symlink $HOME/Dotfiles/xdg-desktop-portal/niri-portals.conf $HOME/.config/xdg-desktop-portal/niri-portals.conf \
     && xdg-mime default dev.duxlabs.files.desktop inode/directory \
     && systemctl --user try-restart xdg-desktop-portal.service"
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
