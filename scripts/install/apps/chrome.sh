#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: google-chrome-stable
#
# Chrome in the wallpaper colors: its launcher entry starts it through
# scripts/wrappers/chrome-theme.sh, which hands Chrome the wallpaper's seed color.

configure_chrome_steps=(
  "Colors from the wallpaper (launcher starts it through chrome-theme.sh)|_chrome_launcher"
)

# About: Chrome follows the wallpaper color.
configure_chrome() {
  print_styled_message "Configuring Google Chrome"
  run_substeps "${configure_chrome_steps[@]}"
}

# A copy of google-chrome.desktop in ~/.local/share/applications wins over the
# system one (same id, so defaults and DMS pins stay); made from it, so running
# the step again follows Chrome's updates.
# About: Starts Chrome through a script that writes the wallpaper color into its profiles first.
_chrome_launcher() {
  local src=/usr/share/applications/google-chrome.desktop dst="$HOME/.local/share/applications/google-chrome.desktop"
  [ -f "$src" ] || { print_error_message "No $src"; return 2; }
  mkdir -p "$(dirname "$dst")"
  sed "s|^Exec=/usr/bin/google-chrome-stable|Exec=$HOME/Dotfiles/scripts/wrappers/chrome-theme.sh|" "$src" >"$dst" &&
    update-desktop-database -q "$(dirname "$dst")" 2>/dev/null
  check_success "Chrome starts in the wallpaper colors (from its next start)"
}
