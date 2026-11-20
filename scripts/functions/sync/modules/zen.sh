#!/bin/bash
#
# Zen browser → Dotfiles/zen-browser. Sourced by sync.sh.
#
# chrome/ (userChrome.css + the Sine mods) is a symlink into Dotfiles, so it
# needs no copying. The mods' settings live only in the profile: the prefs.js
# lines whose keys the mods declare in their preferences.json ("property") are
# written to sine-prefs.js. configure_zen puts them back into prefs.js on a new
# machine; the Sine UI can still change them (user.js would pin them).
# Other Zen files (keyboard shortcuts, sessions) go through the map module.

SYNC_TITLE="Zen browser"
SYNC_DESC="Sine mod settings → zen-browser/sine-prefs.js"

. "$APPS_DIR/zen.sh"   # zen_pick_profile, ZEN_DOTS


# prefs.js lines of the given keys (stdin, one per line), sorted.
_zen_pref_lines() {
  awk 'NR == FNR { k[$0] = 1; next }
       match($0, /^user_pref\("[^"]+"/) { if (substr($0, 12, RLENGTH - 12) in k) print }' \
    - "$1" | LC_ALL=C sort
}


_zen_sync_prefs() {
  local profile="$1" out="$ZEN_DOTS/sine-prefs.js" keys tmp
  local -a prefs_json=()
  mapfile -t prefs_json < <(compgen -G "$profile/chrome/sine-mods/*/preferences.json")
  [ ${#prefs_json[@]} -gt 0 ] || { echo ":: No Sine mods with settings in $profile/chrome"; return 0; }

  keys=$(jq -r '.. | objects | .property? // empty' "${prefs_json[@]}" | sort -u) || {
    print_error_message "Could not read the mods' preferences.json"
    return 1
  }

  tmp=$(mktemp)
  {
    echo "// Settings of the Sine mods in chrome/sine-mods — written by sync.sh (zen),"
    echo "// read back into prefs.js by configure_zen. Do not edit by hand."
    _zen_pref_lines "$profile/prefs.js" <<< "$keys"
  } > "$tmp"

  if cmp -s "$tmp" "$out"; then
    rm -f "$tmp"
    echo ":: unchanged: $out"
  else
    mv "$tmp" "$out"
    echo ":: $(grep -c '^user_pref' "$out") mod setting(s) -> $out"
  fi
}


sync_module() {
  local profile
  profile=$(zen_pick_profile) || return 1
  [ -n "$profile" ] || return 1
  echo ":: Profile: $profile"

  if [ "$(readlink -f "$profile/chrome")" != "$(readlink -f "$ZEN_DOTS/chrome")" ]; then
    echo ":: Note: $profile/chrome is not linked to $ZEN_DOTS/chrome —"
    echo "   mods and userChrome.css changes stay in the profile (configure_zen links it)"
  fi

  _zen_sync_prefs "$profile" || return 1
  print_success_message "Zen synced to $ZEN_DOTS"
}
