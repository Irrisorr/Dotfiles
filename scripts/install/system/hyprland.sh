#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: hyprland
configure_hyprland() {
  print_styled_message "Configuring hyprland and apps/plugins for it"

  execute_command "Enable hyprpm (hyprland plugin manager)" "hyprpm update -s -v"

  execute_command "Configure hyprland directory" "create_symlink $HOME/Dotfiles/hypr $HOME/.config/hypr"

  if command -v hyprlock &>/dev/null; then
    execute_command "Configure hyprlock" "mkdir -p $HOME/.config/hypr && create_symlink $HOME/Dotfiles/hypr/hyprlock.conf $HOME/.config/hypr/hyprlock.conf"
  fi

  if command -v nwg-displays &>/dev/null; then
    print_styled_message "Configuring nwg-displays"
    if confirm_action "configure nwg-displays"; then
      PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
      NWG_DISPLAYS_PATH="/usr/lib/python${PYTHON_VERSION}/site-packages/nwg_displays/main.py"

      if [ -f "$NWG_DISPLAYS_PATH" ]; then
        print_styled_message "Modifying nwg-displays configuration"
        sudo sed -i 's|hypr_config_dir = os.path.join(get_config_home(), "hypr")|hypr_config_dir = os.path.join(get_config_home(), "hypr/conf")|g' "$NWG_DISPLAYS_PATH"
        print_success_message "nwg-displays configured"
      else
        print_error_message "nwg-displays main.py not found at $NWG_DISPLAYS_PATH"
      fi
    fi
  fi

  if command -v hyprpaper &>/dev/null; then
    print_styled_message "Configuring hyprpaper"
    if confirm_action "configure hyprpaper"; then
      mkdir -p $HOME/.config/hypr
      create_symlink "$HOME/Dotfiles/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"

      print_styled_message "Creating wallpaper changer desktop entry"
      if confirm_action "create wallpaper changer desktop entry"; then
        DESKTOP_FILE="/usr/share/applications/Wallpaper changer.desktop"

        sudo tee "$DESKTOP_FILE" >/dev/null <<EOF
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
        sudo chmod ugo+x "$DESKTOP_FILE"
        print_success_message "Wallpaper changer desktop entry created"
      fi
    fi
  fi
}
