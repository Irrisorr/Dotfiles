#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: vesktop
#
# Only switches on the theme DMS writes from the wallpaper with matugen
# (~/.config/vesktop/themes/dank-discord.css); the rest of Vencord's settings
# stay untracked. Native install only: the Ubuntu flatpak can't see that file.

VESKTOP_SETTINGS="$HOME/.config/vesktop/settings/settings.json"
VESKTOP_DMS_THEME="dank-discord.css"

configure_vesktop() {
  print_styled_message "Configuring Vesktop"
  confirm_step "enable the DMS wallpaper theme in Vesktop" || return 1

  if grep -qs 'flatpak run' "$(command -v vesktop)"; then
    echo ":: Vesktop is the flatpak — it can't read DMS's theme in ~/.config/vesktop, skipped"
    return 1
  fi
  if pgrep -x vesktop &>/dev/null; then
    print_error_message "Close Vesktop first — it rewrites its settings on exit"
    return 2
  fi

  mkdir -p "$(dirname "$VESKTOP_SETTINGS")"
  [ -s "$VESKTOP_SETTINGS" ] || echo '{}' > "$VESKTOP_SETTINGS"

  local tmp
  tmp=$(mktemp)
  jq --arg t "$VESKTOP_DMS_THEME" '.enabledThemes = ((.enabledThemes // []) + [$t] | unique)' \
    "$VESKTOP_SETTINGS" > "$tmp" && mv "$tmp" "$VESKTOP_SETTINGS" || {
    rm -f "$tmp"
    print_error_message "Could not update $VESKTOP_SETTINGS"
    return 2
  }
  print_success_message "Vesktop uses $VESKTOP_DMS_THEME (DMS writes it on the next wallpaper change)"
}
