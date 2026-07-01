#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

configure_gtk() {
  execute_command "Configure GTK (removing window control buttons)" "gsettings set org.gnome.desktop.wm.preferences button-layout ':'"
}

enable_bluetooth() {
  execute_command "Enable Bluetooth service" "sudo systemctl enable bluetooth.service"
}

# Menu guard: /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
start_polkit_gnome() {
  execute_command "Start GNOME polkit agent" "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &"
}

# Menu guard: /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
start_polkit_mate() {
  execute_command "Start MATE polkit agent" "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &"
}
