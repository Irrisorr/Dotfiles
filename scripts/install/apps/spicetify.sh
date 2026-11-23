#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"
. "$FUNCTIONS_DIR/spicetify.sh"   # syn_install: Synthesis

# Menu guard: spicetify
#
# Spotify in the wallpaper colors: the "dms-colors" theme's color.ini is a matugen
# template DMS fills on every wallpaper change (matugen/config.toml), its
# post_hook runs `spicetify refresh -s` and the dms-live extension repaints an
# open Spotify.

configure_spicetify_steps=(
  "Link config|_spicetify_link"
  "Keep this machine's Spotify paths out of git|_spicetify_git_filter|git"
  "Let spicetify write into Spotify|_spicetify_perms"
  "Re-apply after Spotify updates (pacman hook)|_spicetify_hook|pacman"
  "Re-apply after Spotify updates (apt hook)|_spicetify_apt_hook|apt-get"
  "Apply (theme dms-colors)|_spicetify_apply|test:has_spotify_prefs"
  "Marketplace (latest release)|_spicetify_marketplace|curl+test:has_spotify_prefs"
  "Listening Stats (latest release)|_spicetify_listening_stats|curl+test:has_spotify_prefs"
  "Synthesis: YouTube Music and SoundCloud in Spotify|_spicetify_synthesis|curl+test:has_spotify_prefs|optional"
)

# About: Spotify in the wallpaper colors with Marketplace and Listening Stats; applies after Spotify's first start.
configure_spicetify() {
  print_styled_message "Configuring spicetify"
  # Arch's package / Spotify's apt repo (see install_source_spotify); looked up
  # here, as the package step may have just installed it.
  SPOTIFY_DIR=$(_first_existing /opt/spotify /usr/share/spotify) ||
    { print_error_message "No Spotify in /opt/spotify or /usr/share/spotify"; return 2; }
  run_substeps "${configure_spicetify_steps[@]}" || return
  has_spotify_prefs || {
    print_success_message "Spotify hasn't run yet, so nothing to apply: start it once, then Post-install → Spicetify (or this step again)"
    return 0
  }
}

# Spotify writes its prefs on its first start; spicetify can't apply without
# them ("Cannot detect Spotify prefs file location").
# Menu guard: test:has_spotify_prefs
has_spotify_prefs() { [ -s "$HOME/.config/spotify/prefs" ]; }

# About: Links the spicetify config and the dms-colors theme.
_spicetify_link() {
  execute_command "Link spicetify" "create_symlink $HOME/Dotfiles/spicetify $HOME/.config/spicetify"
}

# spicetify writes this machine's Spotify and prefs paths and its [Backup]
# version into config-xpui.ini; the filter keeps them out of commits and puts
# them back on a pull (scripts/wrappers/spicetify-config-filter.sh,
# .gitattributes). Git runs filters only where they are registered: per clone.
# About: Keeps this machine's Spotify paths out of commits and puts them back on pull.
_spicetify_git_filter() {
  local f="$HOME/Dotfiles/scripts/wrappers/spicetify-config-filter.sh"
  execute_command "Register the git filter for config-xpui.ini" \
    "git -C $HOME/Dotfiles config filter.spicetify-config.clean '$f clean' && git -C $HOME/Dotfiles config filter.spicetify-config.smudge '$f smudge'"
}

# What spicetify's docs ask for: it patches files inside the package's dir.
# About: Lets spicetify patch Spotify's files (its docs ask for it).
_spicetify_perms() {
  execute_command "Make $SPOTIFY_DIR writable" "sudo chmod a+wr $SPOTIFY_DIR && sudo chmod a+wr -R $SPOTIFY_DIR/Apps"
}

# About: Re-applies spicetify after pacman updates Spotify.
_spicetify_hook() {
  execute_command "Install the pacman hook" \
    "sudo install -Dm755 $HOME/Dotfiles/etc/spicetify-reapply.sh /usr/local/bin/spicetify-reapply && sudo install -Dm644 $HOME/Dotfiles/etc/pacman.d/hooks/spicetify.hook /etc/pacman.d/hooks/spicetify.hook"
}

# About: Re-applies spicetify after apt updates Spotify.
_spicetify_apt_hook() {
  execute_command "Install the apt hook" \
    "sudo install -Dm755 $HOME/Dotfiles/etc/spicetify-reapply.sh /usr/local/bin/spicetify-reapply && sudo install -Dm644 $HOME/Dotfiles/etc/apt/apt.conf.d/99spicetify /etc/apt/apt.conf.d/99spicetify"
}

# xpui.spa is there only while Spotify is unpatched (fresh install or update):
# then back it up first, else just apply the config again. spicetify finds
# Spotify itself on its first run (the paths in config-xpui.ini are blank in git).
# About: Patches Spotify with the dms-colors theme.
_spicetify_apply() {
  if [ -f "$SPOTIFY_DIR/Apps/xpui.spa" ]; then
    execute_command "Back up Spotify and apply spicetify" "spicetify backup apply"
  else
    execute_command "Apply spicetify" "spicetify apply"
  fi
  [ -s "$HOME/.config/spicetify/Themes/dms-colors/color.ini" ] ||
    print_success_message "Spotify takes the wallpaper colors after DMS sets a wallpaper (change it once)"
}

# The official installers (each repo's README); they apply too.
# About: Installs Marketplace, the in-app store for themes and extensions.
_spicetify_marketplace() {
  execute_command "Install Marketplace" "curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh"
}

# About: Installs Listening Stats, your listening history inside Spotify.
_spicetify_listening_stats() {
  execute_command "Install Listening Stats" \
    "curl -fsSL https://raw.githubusercontent.com/Xndr2/listening-stats/main/install.sh | LISTENING_STATS_SKIP_SPICETIFY_INSTALL=1 bash"
}

# Per machine (optional): see syn_install in scripts/functions/spicetify.sh.
# About: Adds YouTube Music and SoundCloud to Spotify's search, with a local Wisp server for playback.
_spicetify_synthesis() {
  syn_install || return
  echo ":: In Spotify: profile menu → Synthesis Spicetify settings → Enable playback, pick the placeholder folder (e.g. ~/Music/Synthesis), Connection test"
}
