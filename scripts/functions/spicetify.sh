#!/bin/bash
#
# spice: spicetify in one menu — theme (DMS wallpaper colors or the one picked
# in Marketplace), Marketplace update and backup, extensions, apply / repair /
# restore. The config is Dotfiles/spicetify (~/.config/spicetify links to it),
# so the picked theme and extensions are remembered there.

. "$HOME/Dotfiles/scripts/lib/common.sh"

SP_DIR="$HOME/Dotfiles/spicetify"
SP_MARKET_BACKUP="$SP_DIR/marketplace-backup.json"
SP_MARKET_INSTALL="https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh"

sp_get() { spicetify config "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'; }

sp_theme_name() {
  case $(sp_get current_theme) in
    dms-colors) echo "DMS — wallpaper colors" ;;
    marketplace) echo "Marketplace — the theme picked there" ;;
    "") echo "none" ;;
    *) sp_get current_theme ;;
  esac
}

sp_market_version() {
  grep -o -m1 'Initializing Spicetify Marketplace v[0-9.]*' "$SP_DIR/CustomApps/marketplace/extension.js" 2>/dev/null | sed 's/.* v//'
}

# The release's tag, as the install script reads it.
sp_market_latest() {
  curl -fsSL -m 10 https://api.github.com/repos/spicetify/marketplace/releases/latest 2>/dev/null |
    jq -r '.tag_name // empty' | sed 's/^v//'
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

# The official installer (wiki: Installation): downloads the latest release
# into CustomApps/marketplace and applies. The picked theme stays.
sp_market_update() {
  local have latest
  have=$(sp_market_version) latest=$(sp_market_latest)
  gum confirm "Marketplace: installed ${have:-none}, latest ${latest:-?}. Install the latest?" </dev/tty || return 0
  curl -fsSL "$SP_MARKET_INSTALL" | sh || { print_error_message "Marketplace install failed"; return 2; }
  print_success_message "Marketplace $(sp_market_version)"
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

# Files in Extensions/ (yours, dms-live); Marketplace ones are managed there.
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
  require_gum spice || return 1
  command -v spicetify &>/dev/null || { print_error_message "spicetify isn't installed: sudo pacman -S spicetify-cli"; return 1; }
  local act
  while true; do
    echo ":: Theme: $(sp_theme_name) · Marketplace $(sp_market_version) · extensions: $(sp_get extensions)"
    act=$(gum choose --header "Spotify (spicetify)" \
      "Theme — DMS wallpaper colors or the Marketplace one" \
      "Update Marketplace — latest release, official installer" \
      "Marketplace backup — save / restore its themes, extensions, snippets" \
      "Extensions — turn your own on / off" \
      "Apply again — after changing the config by hand" \
      "Repair after a Spotify update — back up the new Spotify, apply" \
      "Restore stock Spotify — remove spicetify's changes" \
      "DevTools — enable Spotify's developer tools" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      Theme*) sp_theme ;;
      "Update Marketplace"*) sp_market_update ;;
      "Marketplace backup"*) sp_market_backup ;;
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
