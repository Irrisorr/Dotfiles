#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# The icon theme lives in the dotfiles (icon_theme= in qt5ct.conf / qt6ct.conf):
# Qt apps, Dux files and the DMS tray read it from there (QT_QPA_PLATFORMTHEME=
# qt5ct). This step picks it and also writes it where GTK keeps its own.

# Installed icon themes: an index.theme with Directories= (cursor themes have none).
_icon_themes() {
  local d t
  for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/local/share/icons /usr/share/icons; do
    for t in "$d"/*/index.theme; do
      grep -q '^Directories=' "$t" 2>/dev/null && basename "$(dirname "$t")"
    done
  done | grep -vxE 'hicolor|locolor|default' | sort -u
}

# About: Picks the icon theme of Qt apps, Dux files, the DMS tray and GTK apps (Papirus and others show up once installed).
configure_icon_theme() {
  local cur pick f
  local -a themes=()
  print_styled_message "Icon theme"
  cur=$(sed -n 's/^icon_theme=//p' "$DOTFILES_DIR/qt5ct/qt5ct.conf" 2>/dev/null)
  mapfile -t themes < <(_icon_themes)
  [ ${#themes[@]} -gt 0 ] || { print_error_message "No icon themes installed"; return 2; }
  pick=$(choose_action --header "Icon theme (now: ${cur:-none})" ${cur:+--selected "$cur"} "${themes[@]}") || return 1
  [ -n "$pick" ] || return 1

  for f in "$DOTFILES_DIR/qt5ct/qt5ct.conf" "$DOTFILES_DIR/qt6ct/qt6ct.conf"; do
    [ -f "$f" ] && sed -i "s|^icon_theme=.*|icon_theme=$pick|" "$f"
  done
  command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.interface icon-theme "$pick"
  for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] || continue
    if grep -q '^gtk-icon-theme-name=' "$f"; then
      sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$pick|" "$f"
    else
      sed -i "/^\[Settings\]/a gtk-icon-theme-name=$pick" "$f"
    fi
  done
  print_success_message "Icon theme: $pick — apps take it on their next start (the DMS tray: dms restart)"
}
