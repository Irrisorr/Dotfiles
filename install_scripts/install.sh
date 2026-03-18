#!/bin/bash

. ./functions.sh
. ./../scripts/scripts.sh

set_ru_font
system_update
install_yay


# Installing Window Manager
print_styled_message "Installing Window Manager"
if confirm_action "install window manager"; then
  window_manager=$(choose_action hyprland niri)
  execute_script sudo pacman -S --noconfirm $window_manager
fi

# Installing packages
print_styled_message "Package Installation"
interactive_category_selection


# Configuring niri ecosystem
if [ "$window_manager" == "niri" ]; then
  print_styled_message "Configuring niri and apps/plugins for it"

  execute_command "Configure niri directory" "create_symlink $(pwd)/../niri ~/.config/niri"

  execute_command "Configure dms-shell (panel-bar)" "mkdir -p ~/.config/DankMaterialShell && create_symlink $(pwd)/../DankMaterialShell ~/.config/DankMaterialShell"

  if command -v hyprlock &>/dev/null; then
    execute_command "Configure hyprlock" "mkdir -p ~/.config/hypr && create_symlink $(pwd)/../hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf"
  fi
fi


# Configuring Hyprland ecosystem
if [ "$window_manager" == "hyprland" ]; then

  print_styled_message "Configuring hyprland and apps/plugins for it"

  execute_command "Enable hyprpm (hyprland plugin manager)" "hyprpm update -s -v"

  execute_command "Configure hyprland directory" "create_symlink $(pwd)/../hypr ~/.config/hypr"
  
  if command -v hyprlock &>/dev/null; then
    execute_command "Configure hyprlock" "mkdir -p ~/.config/hypr && create_symlink $(pwd)/../hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf"
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
      mkdir -p ~/.config/hypr
      create_symlink "$(pwd)/..hypr/hyprpaper.conf" "~/.config/hypr/hyprpaper.conf"

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

fi


# Application configurations
print_styled_message "Configuring applications"

# Configuring GTK
execute_command "Configure GTK (removing window control buttons)" "gsettings set org.gnome.desktop.wm.preferences button-layout ':'"

# Enabling Bluetooth service
execute_command "Enable Bluetooth service" "sudo systemctl enable bluetooth.service"

# Start GNOME polkit agent
if command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null; then
  execute_command "Start GNOME polkit agent" "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &"
fi

# Start MATE polkit agent
if command -v /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &>/dev/null; then
  execute_command "Start MATE polkit agent" "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &"
fi

# Configuring SDDM
if command -v sddm &>/dev/null; then
  execute_command "Configure SDDM" "sudo cp -r $(pwd)/../sddm/corners /usr/share/sddm/themes/ && sudo cp $(pwd)/../sddm/default.conf /usr/lib/sddm/sddm.conf.d/default.conf && sudo systemctl enable sddm"
fi

# Thunar configuration
if command -v thunar &>/dev/null; then
  execute_command "Configure Thunar" "mkdir -p ~/.config/Thunar && create_symlink $(pwd)/../thunar/uca.xml ~/.config/Thunar/uca.xml"
fi

# Wofi configuration
if command -v wofi &>/dev/null; then
  execute_command "Configure Wofi" "mkdir -p ~/.config/wofi && create_symlink $(pwd)/../wofi ~/.config/wofi"
fi

# Rofi configuration
if command -v rofi &>/dev/null; then
  execute_command "Configure Rofi" "mkdir -p ~/.config/rofi && create_symlink $(pwd)/../rofi ~/.config/rofi"
fi

# Wlogout configuration
if command -v wlogout &>/dev/null; then
  execute_command "Configure wlogout" "mkdir -p ~/.config/wlogout && create_symlink $(pwd)/../wlogout ~/.config/wlogout"
fi

# Kitty configuration
if command -v kitty &>/dev/null; then
  execute_command "Configure kitty" "mkdir -p ~/.config/kitty && create_symlink $(pwd)/../kitty ~/.config/kitty"
fi

# Fastfetch configuration
if command -v fastfetch &>/dev/null; then
  execute_command "Configure fastfetch" "mkdir -p ~/.config/fastfetch && create_symlink $(pwd)/../fastfetch ~/.config/fastfetch"
fi

# Fish configuration
if command -v fish &>/dev/null; then
  execute_command "Configure fish" "mkdir -p ~/.config/fish && create_symlink $(pwd)/../fish ~/.config/fish && chsh -s /bin/fish"
fi

# Spicetify configuration
if command -v spicetify-cli &>/dev/null; then
  execute_command "Configure spicetify" "mkdir -p ~/.config/spicetify && create_symlink $(pwd)/../spicetify ~/.config/spicetify"
fi

# Git configuration
if command -v git &>/dev/null; then
  execute_command "Configure Git" "git config --global user.name "Irrisorr" && git config --global user.email "zakharkevichg@gmail.com""
fi

# Update user directories
if command -v xdg-user-dirs-update &>/dev/null; then
  execute_command "Update user directories" "xdg-user-dirs-update"
fi

# Zoom configuration
if command -v zoom &>/dev/null || [ -f ~/.config/zoomus.conf ]; then
  print_styled_message "Configuring Zoom"
  if confirm_action "configure Zoom for Wayland"; then
    if [ -f ~/.config/zoomus.conf ]; then
      if grep -q "enableWaylandShare" ~/.config/zoomus.conf; then
        sed -i 's/enableWaylandShare=.*/enableWaylandShare=true/' ~/.config/zoomus.conf
      else
        echo "enableWaylandShare=true" >>~/.config/zoomus.conf
      fi
    else
      echo "enableWaylandShare=true" >~/.config/zoomus.conf
    fi
    print_success_message "Zoom configured for Wayland"
  fi
fi

# Enable fingerprint authentication
if command -v fprintd-enroll &>/dev/null; then
  print_styled_message "Fingerprint Configuration"
  if confirm_action "configure fingerprint authentication"; then
    execute_script sudo systemctl enable fprintd.service
    print_styled_message "Place your finger several times to scan it"
    execute_script fprintd-enroll
    print_styled_message "Place your finger to verify it"
    execute_script fprintd-verify
    print_success_message "Fingerprint service enabled"
  fi
fi

# Java configuration
if command -v java &>/dev/null; then
  set_java_env
fi

# Convert Russian XDG directories to English
# Check if Russian directories exist
convert_xdg_dirs_to_english


# Delete .bak directories from the .config/
execute_command "Delete .bak directories from the .config/" "find ~/.config/ -type d -name "*.bak" -delete"




print_styled_message "Installation complete! Restart your computer for changes to take effect."
if confirm_action "Do u want to reboot"; then
  reboot
fi
