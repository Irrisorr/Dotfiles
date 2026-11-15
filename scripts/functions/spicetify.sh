#!/bin/bash
#
# spice: spicetify in one menu — custom app updates, repair / restore. The
# config is Dotfiles/spicetify (~/.config/spicetify links to it); the theme is
# always dms-colors, the wallpaper colors.

. "$HOME/Dotfiles/scripts/lib/common.sh"

SP_DIR="$HOME/Dotfiles/spicetify"

# Custom apps, each installed and updated by its own official installer:
# name|CustomApps dir|GitHub repo|installer URL|shell it runs in
SP_APPS=(
  "Marketplace|marketplace|spicetify/marketplace|https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh|sh"
  "Listening Stats|listening-stats|Xndr2/listening-stats|https://raw.githubusercontent.com/Xndr2/listening-stats/main/install.sh|bash"
)

# Lists (custom_apps) come one per line.
sp_get() { spicetify config "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | paste -sd' '; }

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

# Installed vs latest release for each app; outdated or missing ones come
# preselected. The installers download into CustomApps/ and apply.
# (Marketplace's own extensions load from GitHub on every Spotify start, so they
# update by themselves.)
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

# xpui.spa is there only while Spotify is stock (fresh install or update): then
# back it up first, else just apply the config again.
sp_repair() {
  if [ -f /opt/spotify/Apps/xpui.spa ]; then sp_run backup apply; else sp_run apply; fi
}

spice() {
  command -v spicetify &>/dev/null || { print_error_message "spicetify isn't installed: sudo pacman -S spicetify-cli"; return 1; }
  require_gum spice || return 1
  local act
  while true; do
    echo ":: Apps: $(sp_get custom_apps)"
    act=$(gum choose --header "Spotify (spicetify)" \
      "Update apps — Marketplace, Listening Stats: latest releases" \
      "Repair — apply again (Spotify stock after an update, config edited by hand)" \
      "Restore stock Spotify — remove spicetify's changes (Repair puts them back)" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      "Update apps"*) sp_apps_update ;;
      Repair*) sp_repair ;;
      "Restore stock"*) gum confirm "Remove spicetify from Spotify? (Repair puts it back)" </dev/tty && sp_run restore ;;
      *) return 0 ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
