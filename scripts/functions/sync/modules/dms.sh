#!/bin/bash
#
# Dux shell state → Dotfiles/dms/session.json. Sourced by sync.sh.
#
# DMS keeps the wallpaper transition and cycling and the lock screen / greeter
# layout in ~/.local/state/dms/session.json, next to things that belong to this
# machine only (launcher history, audio devices, weather location). Only the
# DMS_SESSION_KEYS are copied; the wallpaper path gets "~" for the home, so it
# names no user. The installer's "Dux shell state" step merges them back.

SYNC_TITLE="Dux shell state"
SYNC_DESC="wallpaper transition, lock screen layout → dms/session.json"

. "$SYSTEM_DIR/niri.sh"   # DMS_SESSION_KEYS


sync_module() {
  local live="$HOME/.local/state/dms/session.json" out="$HOME/Dotfiles/dms/session.json" tmp
  [ -s "$live" ] || { print_error_message "No $live (DMS hasn't run here)"; return 1; }
  tmp=$(mktemp)
  if ! jq --argjson k "$DMS_SESSION_KEYS" --arg h "$HOME" '
      with_entries(select(.key as $x | $k | index($x)))
      | if .wallpaperPath then .wallpaperPath |= (if startswith($h + "/") then "~" + .[($h | length):] else . end) else . end
    ' "$live" >"$tmp"; then
    rm -f "$tmp"
    print_error_message "Could not read $live"
    return 1
  fi
  if cmp -s "$tmp" "$out"; then
    rm -f "$tmp"
    echo ":: unchanged: $out"
  else
    mv "$tmp" "$out"
    print_success_message "$(jq 'length' "$out") key(s) -> $out"
  fi
}
