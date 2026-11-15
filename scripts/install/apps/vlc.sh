#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: vlc
#
# VLC 3 is a Qt5 app; QT_QPA_PLATFORMTHEME=gtk3 gives Qt5 no colors, so VLC
# alone runs with qt5ct, whose palette is the one DMS writes from the
# wallpaper (qt5ct/colors/matugen.conf). Other Qt apps keep gtk3 (its file
# dialogs). qt6ct is set up the same way for Qt6 apps (VLC 4).

configure_vlc_steps=(
  "Colors from the wallpaper (qt5ct/qt6ct)|_vlc_colors|qt5ct"
  "Window fills the column, not the video size|_vlc_no_autoresize"
)

configure_vlc() {
  print_styled_message "Configuring VLC"
  run_substeps "${configure_vlc_steps[@]}"
}

# DMS may have written a palette before the link exists; it goes into the
# linked dir instead of the .bak.
_vlc_link_qtct() {
  local v=$1 dir="$HOME/.config/qt${1}ct"
  if [ -d "$dir/colors" ] && [ ! -L "$dir" ]; then
    mkdir -p "$HOME/Dotfiles/qt${v}ct/colors"
    cp -n "$dir/colors/"* "$HOME/Dotfiles/qt${v}ct/colors/" 2>/dev/null
  fi
  create_symlink "$HOME/Dotfiles/qt${v}ct" "$dir"
}

# A copy of vlc.desktop in ~/.local/share/applications wins over the system
# one; made from it so it follows VLC updates when this step is run again.
_vlc_desktop() {
  local src=/usr/share/applications/vlc.desktop dst="$HOME/.local/share/applications/vlc.desktop"
  [ -f "$src" ] || return 2
  mkdir -p "$(dirname "$dst")"
  sed 's|^Exec=|Exec=env QT_QPA_PLATFORMTHEME=qt5ct |' "$src" >"$dst" &&
    update-desktop-database -q "$(dirname "$dst")" 2>/dev/null
  return 0
}

_vlc_colors() {
  execute_command "Link qt5ct" ". $HOME/Dotfiles/scripts/install/apps/vlc.sh && _vlc_link_qtct 5"
  command -v qt6ct &>/dev/null &&
    execute_command "Link qt6ct" ". $HOME/Dotfiles/scripts/install/apps/vlc.sh && _vlc_link_qtct 6"
  execute_command "Start VLC with qt5ct" ". $HOME/Dotfiles/scripts/install/apps/vlc.sh && _vlc_desktop"
  [ -f "$HOME/.config/qt5ct/colors/matugen.conf" ] ||
    print_success_message "The colors appear once DMS sets a wallpaper (change it once)"
}

# VLC resizes its window to the video, wider than a niri column for 1080p.
_vlc_no_autoresize() {
  local rc="$HOME/.config/vlc/vlcrc"
  if [ -f "$rc" ] && grep -q '^#\?qt-video-autoresize=' "$rc"; then
    execute_command "Turn off resizing to the video" "sed -i 's/^#\?qt-video-autoresize=.*/qt-video-autoresize=0/' '$rc'"
  else
    execute_command "Turn off resizing to the video" "mkdir -p '$HOME/.config/vlc' && printf '[qt]\nqt-video-autoresize=0\n' >>'$rc'"
  fi
}
