#!/bin/bash
#
# Starts Google Chrome in the wallpaper's colors: Chrome builds its whole theme
# (tabs, toolbar, new tab page) from one seed color, the way matugen does, so
# the wallpaper's seed (matugen/templates/chrome-color) goes into its settings,
# with the tonal-spot variant DMS uses. Chrome writes its settings back on exit,
# so this only happens while no Chrome runs; a running one keeps its colors
# until it restarts. The launcher entry (configure_chrome) starts Chrome here.
#
#   chrome-theme.sh [chrome args]

color=$(cat "$HOME/.cache/matugen/chrome-color" 2>/dev/null)
if [[ $color =~ ^#[0-9a-fA-F]{6}$ ]] && ! pgrep -x chrome &>/dev/null && command -v jq &>/dev/null; then
  # SkColor is ARGB in a signed 32-bit int.
  c=$((0xFF000000 | 0x${color#\#}))
  ((c > 2147483647)) && c=$((c - 4294967296))
  for prefs in "$HOME"/.config/google-chrome/{Default,Profile\ *}/Preferences; do
    [ -f "$prefs" ] || continue
    tmp=$(mktemp) || break
    jq --argjson c "$c" '
      .browser.theme.user_color2 = $c | .browser.theme.color_variant2 = 1
      | .browser.theme.follows_system_colors = false
      | .extensions.theme.system_theme = 0 | .extensions.theme.id = ""
    ' "$prefs" >"$tmp" && [ -s "$tmp" ] && cat "$tmp" >"$prefs"
    rm -f "$tmp"
  done
fi
exec /usr/bin/google-chrome-stable "$@"
