#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# About: Hides the minimize/maximize/close buttons of GTK apps; the window manager handles windows.
configure_gtk() {
  execute_command "Configure GTK (removing window control buttons)" "gsettings set org.gnome.desktop.wm.preferences button-layout ':'"
}

# About: Starts Bluetooth on every boot.
enable_bluetooth() {
  execute_command "Enable Bluetooth service" "sudo systemctl enable bluetooth.service"
}

# Menu guard: test:has_polkit_gnome
# About: Starts the GNOME password prompt for apps that need root, for this session.
start_polkit_gnome() {
  execute_command "Start GNOME polkit agent" "\"\$(find_polkit_agent gnome)\" &"
}

# Menu guard: test:has_polkit_mate
# About: Starts the MATE password prompt for apps that need root, for this session; niri starts it on login.
start_polkit_mate() {
  execute_command "Start MATE polkit agent" "\"\$(find_polkit_agent mate)\" &"
}
