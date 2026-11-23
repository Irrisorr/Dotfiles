#!/bin/bash
#
# Runs once after the reboot (fish conf.d hook). Like install.sh it is menu-driven:
# every step is a function, listed in one menu() call at the bottom.

. "$HOME/Dotfiles/scripts/lib/common.sh"
require_gum "post-install" || exit 1
. "$APPS_DIR/obsidian.sh"
. "$APPS_DIR/spicetify.sh"
. "$SYSTEM_DIR/xdg.sh"
. "$SYSTEM_DIR/default_apps.sh"
. "$FUNCTIONS_DIR/fonts.sh"   # ft_ui, ft_mono: the fonts chosen with `fonts`


# ─── Step functions ──────────────────────────────────────────────────────────

post_gh_auth() {
  execute_command "Auth github via Github-cli (Browser Required)" "gh auth login"
}

# Menu guard: test:has_telegram_client
has_telegram_client() { command -v telegram-desktop &>/dev/null || command -v ime &>/dev/null || command -v AyuGram &>/dev/null; }

# Steps that need an app started by hand first: prints what to do, waits.
# Returns 1 when the user skips.
_post_wait() {
  local title=$1 i=1 step answer
  shift
  print_styled_message "$title"
  for step in "$@"; do
    echo "  $i. $step"
    i=$((i + 1))
  done
  read -rp ":: Press Enter when done (s + Enter to skip): " answer </dev/tty
  [ "$answer" != s ]
}

# The vaults come from the phone through Syncthing; then ~/Documents can link
# into the vault and every vault gets the wallpaper-colors snippet.
post_obsidian() {
  _post_wait "Obsidian: get your vaults first" \
    "Syncthing (http://127.0.0.1:8384): add the phone, accept the Obsidian folder into ~/Obsidian, wait until it's Up to Date" \
    "Start Obsidian and open every vault once (Open folder as vault)" \
    "Dark mode on (Settings → Appearance); the wallpaper colors work with AnuPpuccin and with Obsidian's own theme" \
    "Settings → Appearance → Font: interface and text $(ft_ui), monospace $(ft_mono)" \
    "Close Obsidian completely (it writes its settings back on exit)" || return 1
  local rc=0
  if has_vault_documents; then
    link_documents_to_vault || rc=$?
  fi
  configure_obsidian
  local r=$?
  [ $r -gt $rc ] && rc=$r
  return $rc
}

# spicetify can't apply before Spotify's first start has written its prefs.
post_spicetify() {
  if ! has_spotify_prefs; then
    _post_wait "Spotify: start it once" \
      "Start Spotify and log in (it creates ~/.config/spotify/prefs)" \
      "Close Spotify" || return 1
    has_spotify_prefs || { print_error_message "Still no ~/.config/spotify/prefs"; return 2; }
  fi
  STEPS_CONFIRMED=1 STEP_ONLY="_spicetify_apply _spicetify_marketplace _spicetify_listening_stats" configure_spicetify
}

# iMe writes its launcher (the .desktop that handles tg://) on its first start;
# the saved default apps point tg:// and ton:// links at that launcher.
post_ime() {
  _post_wait "iMe: start it once" \
    "Start iMe (ime, or Mod+Shift+T) — it writes its launcher" \
    "Close it" || return 1
  STEPS_CONFIRMED=1 STEP_ONLY="_defapps_defaults" configure_default_apps
}

# Telegram clients can't be pointed at a theme file from outside: the matugen
# hook keeps one up to date, the client is told once where it is.
post_telegram() {
  local theme="$HOME/.local/share/matugen/dms.tdesktop-theme"
  [ -s "$theme" ] || { print_error_message "No $theme yet: change the wallpaper once (DMS → Settings → Wallpaper)"; return 2; }
  command -v wl-copy &>/dev/null && printf '%s' "$theme" | wl-copy && echo ":: The theme's path is in the clipboard"
  _post_wait "Telegram / iMe: wallpaper colors and font (in each client you use)" \
    "Settings → Chat Settings → ⋮ (top right) → Choose from file → Ctrl+L, paste: $theme → Apply theme" \
    "Settings → Chat Settings → Font family: $(ft_ui)" \
    "Done once: the client repaints by itself on every wallpaper change" || return 1
}

# The latest release from GitHub: Arch's .pkg.tar.zst or the .deb.
install_rustdesk() {
  local version base url

  print_styled_message "Installing RustDesk"
  version=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$version" ] || { print_error_message "Could not find RustDesk's latest release"; return 2; }
  confirm_action "install RustDesk $version" || return 1

  base="https://github.com/rustdesk/rustdesk/releases/download/$version/rustdesk-$version"
  if is_arch; then
    url="$base-0-x86_64.pkg.tar.zst"
  elif is_debian; then
    url="$base-x86_64.deb"
  else
    print_error_message "No RustDesk package for $DISTRO"
    return 1
  fi

  url_install "$url"
  check_success "RustDesk $version installed"
}

# Menu guard: hyprpm
install_hypr_plugins() {
  print_styled_message "Installing Hyprland plugins"

  # hypr-dynamic-cursors plugin
  print_styled_message "Installing hypr-dynamic-cursors plugin"
  if confirm_action "install hypr-dynamic-cursors plugin"; then
    print_styled_message "Adding hypr-dynamic-cursors plugin"
    execute_command hyprpm add https://github.com/virtcode/hypr-dynamic-cursors

    print_styled_message "Enabling hypr-dynamic-cursors plugin"
    execute_command hyprpm enable dynamic-cursors

    print_success_message "hypr-dynamic-cursors plugin installed and enabled"
  fi
}


# ─── Menu ────────────────────────────────────────────────────────────────────

menu ">>> Finish & reboot <<<" \
  "Update system|system_update" \
  "Auth GitHub (gh)|post_gh_auth|gh" \
  "Obsidian: vaults via Syncthing, Documents link, wallpaper colors|post_obsidian|obsidian" \
  "Spotify: apply spicetify (start Spotify once first)|post_spicetify|spicetify" \
  "iMe: open tg:// links in it (start iMe once first)|post_ime|ime" \
  "Telegram / iMe: wallpaper colors and font (set once in the client)|post_telegram|test:has_telegram_client" \
  "Install RustDesk (latest)|install_rustdesk" \
  "Install Hyprland plugins|install_hypr_plugins|hyprpm"


# ─── Final step ──────────────────────────────────────────────────────────────

execute_command "Reboot device for changes to take effect" "reboot"
