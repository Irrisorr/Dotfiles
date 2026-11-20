#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: hyprland
#
# One action per entry, so the fzf config menu can list them under the step and
# run only the ticked ones (run_substeps in lib/helpers.sh).
configure_hyprland_steps=(
  "Enable hyprpm (plugin manager)|_hypr_hyprpm|hyprpm"
  "hyprland config|_hypr_link_config"
  "hyprlock config|_hypr_link_hyprlock|hyprlock"
  "nwg-displays: write into hypr/conf|_hypr_nwg_displays|nwg-displays"
  "hyprpaper config|_hypr_link_hyprpaper|hyprpaper"
  "Wallpaper changer desktop entry|_hypr_wallpaper_entry|hyprpaper"
)

configure_hyprland() {
  print_styled_message "Configuring hyprland and apps/plugins for it"
  run_substeps "${configure_hyprland_steps[@]}"
}

_hypr_hyprpm() {
  execute_command "Enable hyprpm (hyprland plugin manager)" "hyprpm update -s -v"
}

_hypr_link_config() {
  execute_command "Configure hyprland directory" "create_symlink $HOME/Dotfiles/hypr $HOME/.config/hypr"
}

_hypr_link_hyprlock() {
  execute_command "Configure hyprlock" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprlock.conf $HOME/.config/hypr/hyprlock.conf"
}

_hypr_nwg_displays() {
  local main
  main="$(python_site_dir)/nwg_displays/main.py"
  execute_command "Point nwg-displays at hypr/conf" \
    "[ -f '$main' ] || { echo 'nwg-displays main.py not found at $main' >&2; exit 1; }
     sudo sed -i 's|hypr_config_dir = os.path.join(get_config_home(), \"hypr\")|hypr_config_dir = os.path.join(get_config_home(), \"hypr/conf\")|g' '$main'"
}

_hypr_link_hyprpaper() {
  execute_command "Configure hyprpaper" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprpaper.conf $HOME/.config/hypr/hyprpaper.conf"
}

_hypr_wallpaper_entry() {
  local desktop_file="/usr/share/applications/Wallpaper changer.desktop"
  execute_command "Create wallpaper changer desktop entry" \
    "sudo tee '$desktop_file' >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Hyprpaper Wallpaper Setter
Comment=Приложение для установки обоев через Hyprpaper
Exec=python3 $HOME/.config/hypr/scripts/change-wallpaper.py
Icon=$HOME/Desktop/icon EnjAction.png
Terminal=false
Categories=Utility;
EOF
sudo chmod ugo+x '$desktop_file'"
}
