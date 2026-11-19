#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zed
#
# DMS writes Zed's wallpaper theme itself (~/.config/zed/themes/dank-zed-theme.json,
# matugenTemplateZed); Zed only has to pick it. settings.json stays untracked.

configure_zed_steps=(
  "Theme from the wallpaper (DankShell)|_zed_dms_theme"
)

configure_zed() {
  print_styled_message "Configuring Zed"
  run_substeps "${configure_zed_steps[@]}"
}

# settings.json is JSONC (comments, trailing commas), so no jq: the "light" and
# "dark" lines inside "theme": { … } are rewritten in place, or the block is
# added. Zed reloads its settings itself.
_zed_dms_theme() {
  local settings="$HOME/.config/zed/settings.json" tmp
  mkdir -p "$(dirname "$settings")"
  [ -s "$settings" ] || echo '{}' >"$settings"
  tmp=$(mktemp)
  if grep -q '"theme"[[:space:]]*:[[:space:]]*{' "$settings"; then
    awk '
      /"theme"[[:space:]]*:[[:space:]]*\{/ { inside = 1 }
      inside && /"light"[[:space:]]*:/ { sub(/"light"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"light\": \"DankShell Light\"") }
      inside && /"dark"[[:space:]]*:/  { sub(/"dark"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"dark\": \"DankShell Dark\"") }
      inside && /\}/ { inside = 0 }
      { print }
    ' "$settings" >"$tmp"
  else
    awk 'NR == 1 && sub(/\{/, "{\n  \"theme\": { \"mode\": \"system\", \"light\": \"DankShell Light\", \"dark\": \"DankShell Dark\" },") { print; next } { print }' "$settings" >"$tmp"
  fi
  cat "$tmp" >"$settings" && rm -f "$tmp"
  check_success "Zed uses the DankShell theme (light / dark with the system)"
}
