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
# The guard is optional; without it the entry always shows. With it, the entry
# only shows when the guard passes. Several tokens can be joined with "+", and
# all of them must pass:
#
#   <command>     shows only if that command exists (bare name or absolute path)
#   distro:<id>   shows only on that distro — matches $DISTRO or $DISTRO_FAMILY
#   test:<func>   shows only if that shell function returns 0
#
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
    "Enable Flatpak + Flathub|enable_flatpak|distro:debian" \
    "Enable Bluetooth service|enable_bluetooth" \
    "Start GNOME polkit agent|start_polkit_gnome|test:has_polkit_gnome" \
    "Start MATE polkit agent|start_polkit_mate|test:has_polkit_mate" \
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
  "Install yay|install_yay|distro:arch" \
  "Set cyrillic console font|set_cyrillic_font" \
  "Install Window Manager|install_window_manager" \
  "Install packages|package_category_selection" \
  "App / system configuration|config_menu"


# ─── Final steps ─────────────────────────────────────────────────────────────

run_final_steps
