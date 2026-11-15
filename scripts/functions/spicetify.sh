#!/bin/bash
#
# spice: spicetify in one menu — theme (DMS wallpaper colors or the one picked
# in Marketplace), custom app updates, Marketplace backup, extensions, apply /
# repair / restore. The config is Dotfiles/spicetify (~/.config/spicetify links to it),
# so the picked theme and extensions are remembered there.

. "$HOME/Dotfiles/scripts/lib/common.sh"

SP_DIR="$HOME/Dotfiles/spicetify"
SP_MARKET_BACKUP="$SP_DIR/marketplace-backup.json"

# Custom apps, each installed and updated by its own official installer:
# name|CustomApps dir|GitHub repo|installer URL|shell it runs in
SP_APPS=(
  "Marketplace|marketplace|spicetify/marketplace|https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh|sh"
  "Listening Stats|listening-stats|Xndr2/listening-stats|https://raw.githubusercontent.com/Xndr2/listening-stats/main/install.sh|bash"
)

# Lists (extensions, custom_apps) come one per line.
sp_get() { spicetify config "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | paste -sd' '; }

sp_theme_name() {
  case $(sp_get current_theme) in
    dms-colors) echo "DMS — wallpaper colors" ;;
    marketplace) echo "Marketplace — the theme picked there" ;;
    "") echo "none" ;;
    *) sp_get current_theme ;;
  esac
}

# The version is only in the bundled JS (manifest.json has none).
sp_app_version() {
  local d="$SP_DIR/CustomApps/$1"
  case $1 in
    marketplace) grep -o -m1 'Initializing Spicetify Marketplace v[0-9.]*' "$d/extension.js" 2>/dev/null | sed 's/.* v//' ;;
    listening-stats) grep -o -m1 'APP_VERSION="[^"]*"' "$d/extension.js" 2>/dev/null | cut -d'"' -f2 ;;
  esac
}

# The release's tag, as the install scripts read it.
sp_app_latest() {
  curl -fsSL -m 10 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null |
    jq -r '.tag_name // empty' | sed 's/^v//'
}

sp_app_install() {
  local name=$1 url=$2 shell=$3
  # Listening Stats' installer would install spicetify to ~/.spicetify if it found none.
  curl -fsSL "$url" | LISTENING_STATS_SKIP_SPICETIFY_INSTALL=1 "$shell" ||
    { print_error_message "$name install failed"; return 2; }
}

# spicetify writes into Spotify's files; apply restarts Spotify.
sp_run() {
  spicetify "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'success|error|warning|info' | grep -v '^- '
}

# Both themes stay in Themes/: picking one only switches the config. Marketplace
# keeps its themes in Spotify itself and needs its placeholder theme picked.
# (Its installer takes a theme name of 3 letters or less for "none" — hence
# dms-colors, not dms.)
sp_theme() {
  local t
  t=$(gum choose --header "Theme (now: $(sp_theme_name))" \
    "DMS — wallpaper colors, follows every wallpaper change" \
    "Marketplace — the theme you install in Marketplace → Themes" </dev/tty) || return 0
  case $t in
    DMS*)
      [ -s "$SP_DIR/Themes/dms-colors/color.ini" ] ||
        print_error_message "No colors yet — DMS writes them on the next wallpaper change"
      sp_run config current_theme dms-colors color_scheme dms
      ;;
    Marketplace*)
      [ -d "$SP_DIR/Themes/marketplace" ] || { mkdir -p "$SP_DIR/Themes/marketplace" && echo '[Marketplace]' >"$SP_DIR/Themes/marketplace/color.ini"; }
      sp_run config current_theme marketplace color_scheme ""
      ;;
  esac
  sp_run apply
  print_success_message "Theme: $(sp_theme_name)"
}

# Installed vs latest release for each app; outdated or missing ones come
# preselected. The installers download into CustomApps/ and apply; the picked
# theme stays. (Marketplace's own themes and extensions load from GitHub on
# every Spotify start, so they update by themselves.)
sp_apps_update() {
  local app name dir repo url shell have latest rows=() sel=() picked=() p
  for app in "${SP_APPS[@]}"; do
    IFS='|' read -r name dir repo url shell <<<"$app"
    have=$(sp_app_version "$dir") latest=$(sp_app_latest "$repo")
    rows+=("$name: ${have:-not installed} → ${latest:-?}")
    [ -n "$latest" ] && [ "$have" = "$latest" ] || sel+=("${rows[-1]}")
  done
  mapfile -t picked < <(gum choose --no-limit --header "Install the latest (Space: pick, Enter: install)" \
    --selected "$(IFS=,; echo "${sel[*]}")" "${rows[@]}" </dev/tty) || return 0
  for p in "${picked[@]}"; do
    for app in "${SP_APPS[@]}"; do
      IFS='|' read -r name dir repo url shell <<<"$app"
      [[ $p == "$name:"* ]] || continue
      sp_app_install "$name" "$url" "$shell" && print_success_message "$name $(sp_app_version "$dir")"
    done
  done
}

# Marketplace keeps installed themes, extensions and snippets in Spotify's own
# storage; its Settings → Back up / Restore is the only way out. The JSON goes
# through the clipboard into the dotfiles and back.
sp_market_backup() {
  local act
  act=$(gum choose --header "Marketplace backup ($SP_MARKET_BACKUP)" \
    "Save — after Marketplace → Settings → Back up (it copies the JSON)" \
    "Restore — copy the saved JSON, then Marketplace → Settings → Restore" </dev/tty) || return 0
  command -v wl-paste &>/dev/null ||
    { print_error_message "wl-clipboard isn't installed: sudo pacman -S wl-clipboard"; return 2; }
  case $act in
    Save*)
      local tmp
      tmp=$(mktemp)
      wl-paste >"$tmp" 2>/dev/null
      if jq -e . "$tmp" &>/dev/null; then
        jq . "$tmp" >"$SP_MARKET_BACKUP" && print_success_message "Saved to $SP_MARKET_BACKUP"
      else
        print_error_message "The clipboard has no Marketplace backup — press Back up in Marketplace's settings first"
      fi
      rm -f "$tmp"
      ;;
    Restore*)
      [ -s "$SP_MARKET_BACKUP" ] || { print_error_message "No saved backup yet"; return 2; }
      wl-copy <"$SP_MARKET_BACKUP" && print_success_message "Copied — paste it in Marketplace → Settings → Restore"
      ;;
  esac
}

# Spicy Lyrics keeps its settings only inside Spotify (localStorage
# "SL:settings"): this reads them from Spotify's storage on disk and writes them
# into lyrics-settings.js, which gives them back to a Spotify that hasn't had them.
SP_LYRICS="$SP_DIR/Extensions/lyrics-settings.js"

sp_lyrics_saved() {
  awk '/^  const SAVED = \{/,/^  \};/' "$SP_LYRICS" | sed '1s/.*/{/; $s/.*/}/'
}

sp_lyrics_settings() {
  [[ " $(sp_get extensions) " == *" lyrics-settings.js "* ]] || {
    sp_run config extensions lyrics-settings.js >/dev/null && sp_run apply
    print_success_message "lyrics-settings.js is on — Spotify restarted"
  }
  local json changed
  json=$(python3 -I "$HOME/Dotfiles/scripts/lib/spotify_storage.py" SL:settings 2>/dev/null | jq 'select(type == "object")' 2>/dev/null)
  [ -n "$json" ] || { print_error_message "No Spicy Lyrics settings in Spotify yet — change one in its settings first"; return 2; }
  changed=$(jq -rn --argjson new "$json" --argjson old "$(sp_lyrics_saved | jq -c . 2>/dev/null || echo '{}')" '
    $new | to_entries[] | select($old[.key] != .value) | "  \(.key): \($old[.key] // "—") → \(.value)"')
  [ -n "$changed" ] || { print_success_message "Spicy Lyrics settings are already saved"; return 0; }
  echo "$changed"
  local tmp
  tmp=$(mktemp)
  awk -v json="$json" '
    /^  \/\/ end of saved settings/ { skip = 0 }
    !skip { print }
    /^  \/\/ spice writes the saved settings/ { gsub(/\n/, "\n  ", json); print "  const SAVED = " json ";"; skip = 1 }
  ' "$SP_LYRICS" >"$tmp" && cat "$tmp" >"$SP_LYRICS"
  rm -f "$tmp"
  sp_run refresh -e
  print_success_message "Saved into $SP_LYRICS"
}

# Files in Extensions/ (yours: dms-live, lyrics-settings); Marketplace ones are managed there.
sp_extensions() {
  local on all=() picked=() f
  on=" $(sp_get extensions | tr '|' ' ') "
  for f in "$SP_DIR"/Extensions/*.js; do [ -e "$f" ] && all+=("$(basename "$f")"); done
  [ ${#all[@]} -gt 0 ] || { print_error_message "No files in $SP_DIR/Extensions"; return 0; }
  local sel=()
  for f in "${all[@]}"; do [[ $on == *" $f "* ]] && sel+=("$f"); done
  mapfile -t picked < <(gum choose --no-limit --header "Extensions (Space: on/off, Enter: apply)" \
    --selected "$(IFS=,; echo "${sel[*]}")" "${all[@]}" </dev/tty) || return 0
  for f in "${all[@]}"; do sp_run config extensions "$f-" >/dev/null; done
  for f in "${picked[@]}"; do sp_run config extensions "$f" >/dev/null; done
  sp_run apply
}

spice() {
  command -v spicetify &>/dev/null || { print_error_message "spicetify isn't installed: sudo pacman -S spicetify-cli"; return 1; }
  [ "$1" = lyrics ] && { sp_lyrics_settings; return; }
  require_gum spice || return 1
  local act
  while true; do
    echo ":: Theme: $(sp_theme_name) · apps: $(sp_get custom_apps) · extensions: $(sp_get extensions)"
    act=$(gum choose --header "Spotify (spicetify)" \
      "Theme — DMS wallpaper colors or the Marketplace one" \
      "Update apps — Marketplace, Listening Stats: latest releases" \
      "Marketplace backup — save / restore its themes, extensions, snippets" \
      "Lyrics settings — save Spicy Lyrics' current settings into the dotfiles" \
      "Extensions — turn your own on / off" \
      "Apply again — after changing the config by hand" \
      "Repair after a Spotify update — back up the new Spotify, apply" \
      "Restore stock Spotify — remove spicetify's changes" \
      "DevTools — enable Spotify's developer tools" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      Theme*) sp_theme ;;
      "Update apps"*) sp_apps_update ;;
      "Marketplace backup"*) sp_market_backup ;;
      "Lyrics settings"*) sp_lyrics_settings ;;
      Extensions*) sp_extensions ;;
      Apply*) sp_run apply ;;
      Repair*) sp_run backup apply ;;
      "Restore stock"*) gum confirm "Remove spicetify from Spotify? (Repair puts it back)" </dev/tty && sp_run restore ;;
      DevTools*) sp_run enable-devtools ;;
      *) return 0 ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
