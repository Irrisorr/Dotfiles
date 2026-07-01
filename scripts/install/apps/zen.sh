#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zen-browser
#
# Launches the browser once to generate ~/.config/zen/, finds the *release*
# profile, symlinks every tracked config from Dotfiles/zen-browser/ into it,
# and registers the Zen mods. Everything Zen-related lives in this one file.
configure_zen() {
  print_styled_message "Configuring Zen-Browser"
  if ! confirm_action "configure Zen-Browser"; then
    return 1
  fi

  local zen_config="$CONFIG_DIR/zen"
  local dotfiles_zen="$DOTFILES_DIR/zen-browser"

  if [ ! -d "$zen_config" ]; then
    echo ":: Launching zen-browser to initialise config directory..."
    zen-browser &
    local zen_pid=$!
    local waited=0
    while [ ! -d "$zen_config" ] && [ $waited -lt 30 ]; do
      sleep 3
      waited=$((waited + 1))
    done
    kill "$zen_pid" 2>/dev/null
    wait "$zen_pid" 2>/dev/null
  fi

  if [ ! -d "$zen_config" ]; then
    print_error_message "$zen_config was not created by zen-browser"
    return 2
  fi

  local profile_dir
  profile_dir=$(find "$zen_config" -maxdepth 1 -type d -name "*release*" | head -n 1)
  if [ -z "$profile_dir" ]; then
    print_error_message "No 'release' profile directory found inside $zen_config"
    return 2
  fi

  echo ":: Found profile directory: $profile_dir"

  local item base
  for item in "$dotfiles_zen"/{*,.*}; do
    base="$(basename "$item")"
    [[ "$base" == "." || "$base" == ".." ]] && continue
    [ -e "$item" ] || continue
    create_symlink "$item" "$profile_dir/$base"
  done

  local mods_export="$dotfiles_zen/zen-mods-export.json"
  if [ -f "$mods_export" ]; then
    echo ":: Registering Zen mods from export file..."
    local zen_themes_json="$profile_dir/zen-themes.json"
    if [ -f "$zen_themes_json" ] && [ ! -L "$zen_themes_json" ]; then
      jq -s '.[0] * .[1]' "$zen_themes_json" "$mods_export" > "${zen_themes_json}.tmp" \
        && mv "${zen_themes_json}.tmp" "$zen_themes_json"
    else
      [ -L "$zen_themes_json" ] && rm "$zen_themes_json"
      cp "$mods_export" "$zen_themes_json"
    fi
    check_success "Zen mods registered in $zen_themes_json"
  fi

  check_success "Zen-Browser profile configured at $profile_dir"
}
