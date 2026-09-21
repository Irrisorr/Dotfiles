#!/bin/bash
#
# Dotfiles installer entry point. Run from the repo root:  ./install.sh
#
# This file holds ONLY the menus. The engine (sourcing, core-step functions,
# final steps) lives in scripts/install/main.sh, sourced just below.
#
# Add a config step: write configure_* in scripts/install/{system,apps}/<name>.sh
#                    then add a "Label|func|guard" line to config_menu here.
#
# The guard is optional. If present, the entry will only show if the guard command exists.
# If guard command is not exist, the entry will not show. 
# F.e. if you have niri installed instead of hyprland, 
#                       the entry "Hyprland ecosystem" will not show, 
#                       while "Niri ecosystem" will show.
#
# Adding a core step:   write its function in main.sh, add a line to the first menu.

. "$HOME/Dotfiles/scripts/install/main.sh"


# ─── Configuration submenu ───────────────────────────────────────────────────

config_menu() {
  menu "<─ Back to main menu" \
    "Niri ecosystem|configure_niri|niri" \
    "Hyprland ecosystem|configure_hyprland|hyprland" \
    "SDDM|configure_sddm|sddm" \
    "Enable Bluetooth service|enable_bluetooth" \
    "Start GNOME polkit agent|start_polkit_gnome|/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" \
    "Start MATE polkit agent|start_polkit_mate|/usr/lib/mate-polkit/polkit-mate-authentication-agent-1" \
    "GTK (window control buttons)|configure_gtk" \
    "Update user directories|update_user_dirs|xdg-user-dirs-update" \
    "Convert Russian XDG dirs to English|convert_xdg_dirs" \
    "Fingerprint authentication|configure_fingerprint|fprintd-enroll" \
    "Git|configure_git|git" \
    "Zen Browser|configure_zen|zen-browser" \
    "Kitty|configure_kitty|kitty" \
    "Fish|configure_fish|fish" \
    "Rofi|configure_rofi|rofi" \
    "Spicetify|configure_spicetify|spicetify-cli" \
    "Thunar|configure_thunar|thunar" \
    "Wlogout|configure_wlogout|wlogout" \
    "Wofi|configure_wofi|wofi" \
    "Clipse|configure_clipse|clipse" \
    "Fastfetch|configure_fastfetch|fastfetch" \
    "Zoom|configure_zoom|zoom" \
    "Java|configure_java|java"
}


# ─── First menu ──────────────────────────────────────────────────────────────

menu ">>> Finish & continue <<<" \
  "Update system|system_update" \
  "Install yay|install_yay" \
  "Set cyrillic console font|set_cyrillic_font" \
  "Install Window Manager|install_window_manager" \
  "Install packages|package_category_selection" \
  "App / system configuration|config_menu"


# ─── Final steps ─────────────────────────────────────────────────────────────

run_final_steps
