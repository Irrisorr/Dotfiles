#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: vlc
#
# Its wallpaper colors come with every Qt app's now (qt5ct / qt6ct, see the
# niri ecosystem step "Qt apps: wallpaper colors").

configure_vlc_steps=(
  "Window fills the column, not the video size|_vlc_no_autoresize"
)

configure_vlc() {
  print_styled_message "Configuring VLC"
  run_substeps "${configure_vlc_steps[@]}"
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
