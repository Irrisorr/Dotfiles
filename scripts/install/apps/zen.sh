#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: zen-browser
#
# Everything Zen-related lives here. configure_zen (install-time) launches the
# browser once to generate ~/.config/zen/, symlinks the tracked configs from
# Dotfiles/zen-browser/, registers the mods, and optionally restores the private
# files. restore_private_zen is shared with post_install.sh.

# Find the *release* profile dir inside ~/.config/zen (prints nothing if none).
_zen_find_profile() {
  local zen_config="$CONFIG_DIR/zen"
  [ -d "$zen_config" ] || return 0
  find "$zen_config" -maxdepth 1 -type d -name "*release*" | head -n 1
}

# Restore private/sensitive Zen files from ~/Dotfiles-private/zen-browser into a
# profile: copy the live files (sessions, search, ...) and import any *.sql table
# dumps into the profile's places.sqlite. Shared by configure_zen + post_install.
restore_private_zen() {
  local profile_dir="$1"
  local private_zen="$PRIVATE_DIR/zen-browser"
  [ -d "$private_zen" ] || return 0
  [ -n "$profile_dir" ] || return 1

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
  profile_dir=$(_zen_find_profile)
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

  # Restore private files (sessions, bookmark-workspaces table, ...) if the
  # private repo is present on this machine.
  if [ -d "$PRIVATE_DIR/zen-browser" ] \
     && confirm_action "restore private Zen files (sessions, workspaces) into the profile"; then
    restore_private_zen "$profile_dir"
    check_success "Private Zen files restored"
  fi

  # create_symlink leaves *.bak backups of anything it replaced — offer cleanup.
  if [ -n "$(find "$profile_dir" -maxdepth 1 -name '*.bak' -print -quit)" ]; then
    if confirm_action "delete .bak backups left in the Zen profile"; then
      find "$profile_dir" -maxdepth 1 -name '*.bak' -exec rm -rf {} +
      print_success_message "Removed .bak backups from $profile_dir"
    fi
  fi

  check_success "Zen-Browser profile configured at $profile_dir"
}
