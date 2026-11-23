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

# Synthesis Spicetify: YouTube Music and SoundCloud in Spotify's search. Per
# machine, not in git: its file is in .gitignore and the config filter drops it
# from the extensions line in commits. Playback needs a local Wisp proxy (YouTube
# turns away the shared ones); the repo's wisp_ondemand.py installs wisp-js with
# npm and starts it on demand through systemd user units.
SYN_REPO="kagamiomochi/Synthesis-Spicetify"
SYN_FILE="synthesis-spicetify.js"
SYN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/synthesis-spicetify"

syn_installed() { [ -f "$SP_DIR/Extensions/$SYN_FILE" ]; }

syn_version() {
  grep -o -m1 'const VERSION = "v[^"]*"' "$SP_DIR/Extensions/$SYN_FILE" 2>/dev/null | cut -d'"' -f2 | sed 's/^v//'
}

# The repo has tags only, no GitHub releases.
syn_latest() {
  curl -fsSL -m 10 "https://api.github.com/repos/$SYN_REPO/tags" 2>/dev/null |
    jq -r '.[].name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 | sed 's/^v//'
}

# Install and update alike: the extension and the Wisp launcher from the same
# tag. Running the launcher's install again picks up a new Node.js path or wisp-js pin.
syn_install() {
  local ver raw tmp rc=0
  ver=$(syn_latest)
  [ -n "$ver" ] || { print_error_message "Couldn't find Synthesis' latest tag"; return 2; }
  raw="https://raw.githubusercontent.com/$SYN_REPO/v$ver"
  tmp=$(mktemp -d)
  if ! curl -fsSL "$raw/$SYN_FILE" -o "$tmp/$SYN_FILE" ||
    ! curl -fsSL "$raw/wisp-launcher/portable/wisp_ondemand.py" -o "$tmp/wisp_ondemand.py"; then
    print_error_message "Synthesis v$ver download failed"
    rm -rf "$tmp"
    return 2
  fi
  # The tagged file still carries the previous VERSION (the repo's CI bumps it on
  # main after tagging); set it like the CI does, so the extension and
  # Update apps see the real one.
  sed -i "s|/\* VERSION \*/ const VERSION = \"[^\"]*\";|/* VERSION */ const VERSION = \"v$ver\";|" "$tmp/$SYN_FILE"
  mkdir -p "$SP_DIR/Extensions" && mv "$tmp/$SYN_FILE" "$SP_DIR/Extensions/$SYN_FILE"
  [[ " $(sp_get extensions) " == *" $SYN_FILE "* ]] || spicetify config extensions "$SYN_FILE" >/dev/null
  # Without it search still works, only playback doesn't.
  if command -v python3 &>/dev/null && command -v npm &>/dev/null; then
    python3 -I "$tmp/wisp_ondemand.py" install || rc=2
  else
    rc=2
  fi
  [ $rc -eq 0 ] || print_error_message "No local Wisp server: playback needs python3, npm and Node.js 22.18+ (or 24.11+)"
  rm -rf "$tmp"
  sp_run apply
  [ $rc -eq 0 ] && print_success_message "Synthesis $ver"
  return $rc
}

# The placeholder folder (Spotify's Local Files source) stays: playlists may hold its files.
syn_remove() {
  [ -f "$SYN_DATA/wisp_ondemand.py" ] && python3 -I "$SYN_DATA/wisp_ondemand.py" uninstall
  rm -rf "$SYN_DATA"
  spicetify config extensions "$SYN_FILE-" >/dev/null
  rm -f "$SP_DIR/Extensions/$SYN_FILE" "/opt/spotify/Apps/xpui/extensions/$SYN_FILE" "/usr/share/spotify/Apps/xpui/extensions/$SYN_FILE"
  sp_run apply
  print_success_message "Synthesis removed (its placeholder folder stays; remove it from Spotify's Local Files yourself)"
}

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
  if syn_installed; then
    have=$(syn_version) latest=$(syn_latest)
    rows+=("Synthesis: ${have:-?} → ${latest:-?}")
    [ -n "$latest" ] && [ "$have" = "$latest" ] || sel+=("${rows[-1]}")
  fi
  mapfile -t picked < <(gum choose --no-limit --header "Install the latest (Space: pick, Enter: install)" \
    --selected "$(IFS=,; echo "${sel[*]}")" "${rows[@]}" </dev/tty) || return 0
  for p in "${picked[@]}"; do
    [[ $p == Synthesis:* ]] && { syn_install; continue; }
    for app in "${SP_APPS[@]}"; do
      IFS='|' read -r name dir repo url shell <<<"$app"
      [[ $p == "$name:"* ]] || continue
      sp_app_install "$name" "$url" "$shell" && print_success_message "$name $(sp_app_version "$dir")"
    done
  done
}

# xpui.spa is there only while Spotify is stock (fresh install or update): then
# back it up first, else just apply the config again. /opt/spotify on Arch,
# /usr/share/spotify from Spotify's apt repo.
sp_repair() {
  if [ -f /opt/spotify/Apps/xpui.spa ] || [ -f /usr/share/spotify/Apps/xpui.spa ]; then
    sp_run backup apply
  else
    sp_run apply
  fi
}

spice() {
  command -v spicetify &>/dev/null || { print_error_message "spicetify isn't installed: sudo pacman -S spicetify-cli"; return 1; }
  require_gum spice || return 1
  local act syn
  while true; do
    echo ":: Apps: $(sp_get custom_apps)"
    if syn_installed; then
      syn="Synthesis — remove it from this machine (extension and local Wisp server)"
    else
      syn="Synthesis — install on this machine: YouTube Music and SoundCloud in Spotify"
    fi
    act=$(gum choose --header "Spotify (spicetify)" \
      "Update apps — Marketplace, Listening Stats (and Synthesis, if here): latest releases" \
      "Repair — apply again (Spotify stock after an update, config edited by hand)" \
      "Restore stock Spotify — remove spicetify's changes (Repair puts them back)" \
      "$syn" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      "Update apps"*) sp_apps_update ;;
      "Synthesis — remove"*) gum confirm "Remove Synthesis and its local Wisp server?" </dev/tty && syn_remove ;;
      "Synthesis — install"*) syn_install ;;
      Repair*) sp_repair ;;
      "Restore stock"*) gum confirm "Remove spicetify from Spotify? (Repair puts it back)" </dev/tty && sp_run restore ;;
      *) return 0 ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
