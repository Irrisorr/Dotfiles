#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

configure_gtk() {
  execute_command "Configure GTK (removing window control buttons)" "gsettings set org.gnome.desktop.wm.preferences button-layout ':'"
}

enable_bluetooth() {
  execute_command "Enable Bluetooth service" "sudo systemctl enable bluetooth.service"
}

# Menu guard: test:has_polkit_gnome
start_polkit_gnome() {
  execute_command "Start GNOME polkit agent" "\"\$(find_polkit_agent gnome)\" &"
}

# Menu guard: test:has_polkit_mate
start_polkit_mate() {
  execute_command "Start MATE polkit agent" "\"\$(find_polkit_agent mate)\" &"
}
