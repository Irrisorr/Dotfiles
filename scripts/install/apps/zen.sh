#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zen-browser
#
# Everything Zen-related lives here. configure_zen (install-time) picks the
# profile — launching the browser once to create it on a fresh install — then
# runs the actions below. Restoring the private files is done later by
# post_install.sh (after Mozilla login) via restore_private_zen.
#
# Works for the native package (Arch) and the flatpak (Ubuntu, where
# `zen-browser` is a shim around `flatpak run`). The profile root differs per
# install — zen_profile_root in lib/paths.sh knows all of them. Sine needs the
# native package: its bootloader goes into the browser's own (root) dir.
#
# Mods: the profile's chrome/ is a symlink to Dotfiles/zen-browser/chrome, which
# holds userChrome.css and the Sine mods (sine-mods/). Their settings are kept in
# zen-browser/sine-prefs.js — written by `sync.sh zen`, put back into prefs.js
# here.

configure_zen_steps=(
  "Link Zen configs (chrome, user.js, shortcuts)|_zen_link_configs"
  "Install Sine mod manager|install_sine|test:_zen_sine_supported"
  "Restore Sine mod settings|_zen_import_sine_prefs"
)

ZEN_DOTS="$DOTFILES_DIR/zen-browser"
SINE_ENGINE_JSON="https://raw.githubusercontent.com/CosmoCreeper/Sine/main/engine.json"


# Profiles as "<abs path>\t<name>", the one Zen starts by default first.
zen_profiles() {
  local root
  root=$(zen_profile_root) || return 0
  [ -f "$root/profiles.ini" ] || return 0
  local default
  default=$(awk -F= '/^Default=/ { print $2; exit }' "$root/installs.ini" 2>/dev/null)
  awk -F= -v root="$root" -v def="$default" '
    /^\[/ { if (path != "") out(); path = ""; name = ""; rel = 1; next }
    $1 == "Name" { name = $2 }
    $1 == "Path" { path = $2 }
    $1 == "IsRelative" { rel = $2 }
    function out(  p) {
      p = rel ? root "/" path : path
      if (path == def) first = p "\t" name; else rest = rest p "\t" name "\n"
    }
    END { if (path != "") out(); if (first != "") print first; printf "%s", rest }
  ' "$root/profiles.ini"
}


# The default profile dir, no questions asked (prints nothing if none).
_zen_find_profile() {
  zen_profiles | head -n 1 | cut -f1
}


# Asks which profile when there are several; prints its dir.
zen_pick_profile() {
  local profiles
  profiles=$(zen_profiles)
  [ -n "$profiles" ] || { print_error_message "No Zen profiles (~/.config/zen or the flatpak dir)" >&2; return 1; }

  if [ "$(printf '%s\n' "$profiles" | wc -l)" -eq 1 ]; then
    cut -f1 <<< "$profiles"
  elif fzf_ready; then
    fzf_base_opts "Zen profile" "$(fzf_keys "j/k ↑↓" move Enter pick Esc quit)"
    awk -F'\t' '{ printf "%s\t%s  \033[90m%s\033[0m\n", $1, $2, $1 }' <<< "$profiles" |
      fzf "${FZF_OPTS[@]}" | cut -f1
  else
    local name
    name=$(cut -f2 <<< "$profiles" | gum choose --header "Zen profile" </dev/tty) || return 1
    awk -F'\t' -v n="$name" '$2 == n { print $1; exit }' <<< "$profiles"
  fi
}


_zen_running() {
  pgrep -x zen-bin &>/dev/null
}


# Starts Zen headless for <seconds> and stops it again. Creates the profile on a
# fresh install, lets Sine register itself after its install.
_zen_headless_run() {
  local secs="$1" pid
  zen-browser --headless &>/dev/null &
  pid=$!
  sleep "$secs"
  kill "$pid" 2>/dev/null
  is_zen_flatpak && flatpak kill "$ZEN_FLATPAK_ID" 2>/dev/null
  wait "$pid" 2>/dev/null
}


# Restore private/sensitive Zen files from ~/Dotfiles-private/zen-browser into a
# profile: copy the live files (sessions, search, ...) and import any *.sql table
# dumps into the profile's places.sqlite. Shared by configure_zen + post_install.
restore_private_zen() {
  local profile_dir="$1"
  [ -n "$profile_dir" ] || return 1

  # Pull first so a repo cloned earlier isn't stale (files updated on GitHub
  # would otherwise never reach an existing local clone).
  if [ -d "$PRIVATE_DIR/.git" ] && command -v git &>/dev/null; then
    echo ":: Updating private repo ($PRIVATE_DIR)..."
    git -C "$PRIVATE_DIR" pull
  fi

  local private_zen="$PRIVATE_DIR/zen-browser"
  [ -d "$private_zen" ] || return 0

  # Copy (not symlink) — the browser rewrites these at runtime. Skip *.sql:
  # those are sqlite table dumps, imported below rather than copied as files.
  local item base
  for item in "$private_zen"/{*,.*}; do
    base="$(basename "$item")"
    [[ "$base" == "." || "$base" == ".." ]] && continue
    [ -e "$item" ] || continue
    [[ "$base" == *.sql ]] && continue
    cp -rf "$item" "$profile_dir/"
  done

  # Import table dumps into places.sqlite (dump filename == table name).
  local places="$profile_dir/places.sqlite"
  if command -v sqlite3 &>/dev/null && [ -f "$places" ]; then
    local sql table
    for sql in "$private_zen"/*.sql; do
      [ -e "$sql" ] || continue
      table="$(basename "$sql" .sql)"
      echo ":: Importing table '$table' into places.sqlite"
      sqlite3 "$places" "DROP TABLE IF EXISTS $table;"
      sqlite3 "$places" < "$sql"
    done
  fi
}


configure_zen() {
  print_styled_message "Configuring Zen-Browser"
  confirm_step "configure Zen-Browser" || return 1

  if _zen_running; then
    print_error_message "Close Zen first — it rewrites its profile on exit"
    return 2
  fi

  if [ -z "$(_zen_find_profile)" ]; then
    # Headless: creates the profile without opening a window (works over ssh
    # or a serial console too).
    echo ":: Launching zen-browser once to create its profile..."
    zen-browser --headless &>/dev/null &
    local zen_pid=$! waited=0
    while [ -z "$(_zen_find_profile)" ] && [ $waited -lt 60 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    sleep 2   # let it finish writing the new profile
    kill "$zen_pid" 2>/dev/null
    is_zen_flatpak && flatpak kill "$ZEN_FLATPAK_ID" 2>/dev/null
    wait "$zen_pid" 2>/dev/null
  fi

  ZEN_PROFILE=$(zen_pick_profile)
  if [ -z "$ZEN_PROFILE" ]; then
    print_error_message "No Zen profile — zen-browser did not create one"
    return 2
  fi
  echo ":: Profile: $ZEN_PROFILE"

  run_substeps "${configure_zen_steps[@]}"
}


# Symlinks everything in Dotfiles/zen-browser into the profile — chrome/ as a
# whole, so the mods Sine installs or updates land in Dotfiles.
_zen_link_configs() {
  # The flatpak sandbox can't see ~/Dotfiles, so the symlinks below would point
  # at nothing from inside it. Let it read just the tracked Zen configs.
  if is_zen_flatpak; then
    echo ":: Allowing the Zen flatpak to read $ZEN_DOTS"
    flatpak override --user --filesystem="$ZEN_DOTS:ro" "$ZEN_FLATPAK_ID" || return 2
  fi

  local item base
  for item in "$ZEN_DOTS"/{*,.*}; do
    base="$(basename "$item")"
    [[ "$base" == "." || "$base" == ".." ]] && continue
    [[ "$base" == "sine-prefs.js" ]] && continue   # read into prefs.js, not linked
    [ -e "$item" ] || continue
    create_symlink "$item" "$ZEN_PROFILE/$base" || return 2
  done

  # create_symlink leaves *.bak backups of anything it replaced — offer cleanup.
  if [ -n "$(find "$ZEN_PROFILE" -maxdepth 1 -name '*.bak' -print -quit)" ]; then
    if confirm_action "delete .bak backups left in the Zen profile"; then
      find "$ZEN_PROFILE" -maxdepth 1 -name '*.bak' -exec rm -rf {} +
      print_success_message "Removed .bak backups from $ZEN_PROFILE"
    fi
  fi
  return 0
}


_zen_sine_supported() {
  ! is_zen_flatpak && zen_install_dir &>/dev/null
}


# Sine (github.com/CosmoCreeper/Sine) via its own updater.sh — what the GUI
# installer runs too: the engine goes into <profile>/chrome (JS/, utils/; mods
# are kept with -s), the bootloader (config.js) into the browser dir, for which
# it asks for root itself through pkexec. Versions come from Sine's engine.json,
# like the GUI installer's.
install_sine() {
  local browser_dir engine boot sine tmp
  browser_dir=$(zen_install_dir) || { print_error_message "Zen install dir not found"; return 2; }

  engine=$(curl -fsSL "$SINE_ENGINE_JSON") || { print_error_message "Could not fetch $SINE_ENGINE_JSON"; return 2; }
  boot=$(jq -r '.bootloader' <<< "$engine")
  sine=$(jq -r '.updates[0].version' <<< "$engine")
  echo ":: Sine $sine, bootloader $boot -> $browser_dir"

  tmp=$(mktemp -d)
  if ! curl -fsSL -o "$tmp/updater.sh" "https://github.com/CosmoCreeper/Sine/releases/download/v$sine/updater.sh"; then
    print_error_message "Could not download Sine's updater.sh"
    rm -rf "$tmp"
    return 2
  fi
  chmod +x "$tmp/updater.sh"
  # Absolute path: the script re-runs itself as "$0" through pkexec.
  "$tmp/updater.sh" -s --browser "$browser_dir" --profile "$ZEN_PROFILE" \
    --bootloader "$boot" --version "$sine"
  rm -rf "$tmp"

  if [ ! -f "$ZEN_PROFILE/chrome/JS/sine.sys.mjs" ] || [ ! -f "$browser_dir/config.js" ]; then
    print_error_message "Sine is not fully installed (engine or bootloader missing)"
    return 2
  fi

  # The installer's own last step on Linux; Zen keeps the old chrome code otherwise.
  rm -rf "$HOME/.cache/zen/$(basename "$ZEN_PROFILE")/startupCache"
  # Sine's settings page stays empty on the very first start — get that over with.
  echo ":: Starting Zen once in the background so Sine registers itself..."
  _zen_headless_run 10
  print_success_message "Sine $sine installed"
}


# Puts sine-prefs.js into prefs.js: drops the profile's lines for those keys and
# appends the tracked ones. Plain prefs, so the Sine UI can still change them.
_zen_import_sine_prefs() {
  local src="$ZEN_DOTS/sine-prefs.js" prefs="$ZEN_PROFILE/prefs.js" tmp
  [ -f "$src" ] || { echo ":: No $src — nothing to restore"; return 1; }
  if _zen_running; then
    print_error_message "Close Zen first — it rewrites prefs.js on exit"
    return 2
  fi

  touch "$prefs"
  tmp=$(mktemp)
  awk 'NR == FNR {
         if (match($0, /^user_pref\("[^"]+"/)) k[substr($0, 1, RLENGTH)] = 1
         next
       }
       match($0, /^user_pref\("[^"]+"/) && (substr($0, 1, RLENGTH) in k) { next }
       { print }' "$src" "$prefs" > "$tmp"
  grep '^user_pref' "$src" >> "$tmp"
  mv "$tmp" "$prefs" || { print_error_message "Could not write $prefs"; return 2; }
  print_success_message "Restored $(grep -c '^user_pref' "$src") Sine mod setting(s) into $prefs"
}
