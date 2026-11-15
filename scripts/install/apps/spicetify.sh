#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: spicetify
#
# Spotify in the wallpaper colors: the "dms-colors" theme's color.ini is a matugen
# template DMS fills on every wallpaper change (matugen/config.toml), its
# post_hook runs `spicetify refresh -s` and the dms-live extension repaints an
# open Spotify. Marketplace themes replace "dms-colors" while one is picked.

SPOTIFY_DIR=/opt/spotify

configure_spicetify_steps=(
  "Link configs (spicetify, matugen templates)|_spicetify_link"
  "Let spicetify write into Spotify|_spicetify_perms"
  "Re-apply after Spotify updates (pacman hook)|_spicetify_hook|pacman"
  "Apply (theme dms-colors)|_spicetify_apply"
  "Marketplace (latest release)|_spicetify_marketplace|curl"
)

configure_spicetify() {
  print_styled_message "Configuring spicetify"
  [ -d "$SPOTIFY_DIR" ] || { print_error_message "No Spotify in $SPOTIFY_DIR"; return 2; }
  run_substeps "${configure_spicetify_steps[@]}"
}

_spicetify_link() {
  execute_command "Link spicetify" "create_symlink $HOME/Dotfiles/spicetify $HOME/.config/spicetify"
  execute_command "Link matugen templates" "create_symlink $HOME/Dotfiles/matugen $HOME/.config/matugen"
}

# What spicetify's docs ask for: it patches files inside the package's dir.
_spicetify_perms() {
  execute_command "Make $SPOTIFY_DIR writable" "sudo chmod a+wr $SPOTIFY_DIR && sudo chmod a+wr -R $SPOTIFY_DIR/Apps"
}

_spicetify_hook() {
  execute_command "Install the pacman hook" \
    "sudo install -Dm644 $HOME/Dotfiles/etc/pacman.d/hooks/spicetify.hook /etc/pacman.d/hooks/spicetify.hook"
}

# xpui.spa is there only while Spotify is unpatched (fresh install or update):
# then back it up first, else just apply the config again.
_spicetify_apply() {
  if [ -f "$SPOTIFY_DIR/Apps/xpui.spa" ]; then
    execute_command "Back up Spotify and apply spicetify" "spicetify backup apply"
  else
    execute_command "Apply spicetify" "spicetify apply"
  fi
  [ -s "$HOME/.config/spicetify/Themes/dms-colors/color.ini" ] ||
    print_success_message "Spotify takes the wallpaper colors after DMS sets a wallpaper (change it once)"
}

# The official installer (Marketplace wiki: Installation); it applies too.
_spicetify_marketplace() {
  execute_command "Install Marketplace" "curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh"
}
