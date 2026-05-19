#!/bin/bash

. $HOME/Dotfiles/install_scripts/functions.sh
. $HOME/Dotfiles/install_scripts/gum_functions.sh


#= Rain animation
terminal_rain() {
  terminal-rain "$@"
}


#= Rain animation in mini floating window
terminal_rain_float() {
  niri msg action set-window-height 300
  niri msg action set-window-width 400
  niri msg action toggle-window-floating
  terminal-rain "$@"
}


#= Nvim launch
nvim_launch() {
  niri msg action set-column-width "100%"
  niri msg action move-window-to-workspace ide
  nvim "$@"
}


#= Set new env var
set_env() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_name" ]; then
    if $HAS_GUM; then
      var_name=$(gum input --placeholder "Variable name" < /dev/tty)
    else
      read -p "Variable name: " var_name
    fi
    [ -z "$var_name" ] && return 1
  fi

  if [ -z "$var_value" ]; then
    if $HAS_GUM; then
      var_value=$(gum input --placeholder "Value for $var_name" < /dev/tty)
    else
      read -p "Value for $var_name: " var_value
    fi
    [ -z "$var_value" ] && return 1
  fi

  if [ -d $HOME/.config/fish ]; then
    mkdir -p $HOME/.config/fish
    if grep -q "set -x $var_name" $HOME/.config/fish/config.fish; then
      sed -i "s|set -x $var_name .*|set -x $var_name $var_value|g" $HOME/.config/fish/config.fish
    else
      echo "set -x $var_name $var_value" >>$HOME/.config/fish/config.fish
    fi
    print_success_message "Set $var_name=$var_value env.
Run 'source ~/.config/fish/config.fish' to apply changes
or just open new terminal"
  fi
}


#= Delete env var
delete_env() {
  local var_name="$1"

  if [ -z "$var_name" ]; then
    if [ -f "$HOME/.config/fish/config.fish" ]; then
      local vars_array=()
      while IFS= read -r v; do
        [ -n "$v" ] && vars_array+=("$v")
      done <<< "$(grep "^set -x " "$HOME/.config/fish/config.fish" | sed 's/^set -x \([^ ]*\) \(.*\)/\1=\2/')"

      if [ ${#vars_array[@]} -gt 0 ] && $HAS_GUM; then
        local selection=$(gum choose --height 15 "${vars_array[@]}" < /dev/tty)
        [ -z "$selection" ] && return 1
        var_name="${selection%%=*}"
      else
        if $HAS_GUM; then
          var_name=$(gum input --placeholder "Variable name to delete" < /dev/tty)
        else
          read -p "Variable name to delete: " var_name
        fi
      fi
    fi
    [ -z "$var_name" ] && return 1
  fi

  if [ -f "$HOME/.config/fish/config.fish" ]; then
    if grep -q "set -x $var_name " "$HOME/.config/fish/config.fish"; then
      sed -i "/set -x $var_name /d" "$HOME/.config/fish/config.fish"
      print_success_message "Deleted $var_name env.
Run 'source ~/.config/fish/config.fish' to apply changes
or just open new terminal"
    else
      print_error_message "'$var_name' env not found"
    fi
  fi
}


#= Set JAVA_HOME env var with existing java versions on the system
set_java_env() {
  print_styled_message "Configuring Java"
  if confirm_action "configure Java environment"; then
    java_dirs=($(find /usr/lib/jvm -maxdepth 1 -type d -name "*java*" ! -name "jvm" | sort))
    
    if [ ${#java_dirs[@]} -gt 0 ]; then
      echo "Available Java versions:"
      for i in "${!java_dirs[@]}"; do
        echo "$((i+1))) ${java_dirs[$i]##*/}"
      done
      
      read -p "Select Java version (enter number): " java_choice
      
      if [[ $java_choice =~ ^[0-9]+$ ]] && [ "$java_choice" -gt 0 ] && [ "$java_choice" -le ${#java_dirs[@]} ]; then
        selected_java="${java_dirs[$((java_choice-1))]}"
        
        # Configure bashrc
        if grep -q "export JAVA_HOME" $HOME/.bashrc; then
          sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$selected_java|g" $HOME/.bashrc
        else
          echo "export JAVA_HOME=$selected_java" >>$HOME/.bashrc
        fi
        
        # Configure zshrc
        if grep -q "export JAVA_HOME" $HOME/.zshrc; then
          sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$selected_java|g" $HOME/.zshrc
        else
          echo "export JAVA_HOME=$selected_java" >>$HOME/.zshrc
        fi
        
        # Configure fish
        if [ -d $HOME/.config/fish ]; then
          mkdir -p $HOME/.config/fish
          if grep -q "set -x JAVA_HOME" $HOME/.config/fish/config.fish; then
            sed -i "s|set -x JAVA_HOME .*|set -x JAVA_HOME $selected_java|g" $HOME/.config/fish/config.fish
          else
            echo "set -x JAVA_HOME $selected_java" >>$HOME/.config/fish/config.fish
          fi
        fi
        
        print_success_message "Java environment configured: $selected_java.
Run 'source ~/.config/fish/config.fish' to apply changes
or just open new terminal"
      else
        print_error_message "Invalid selection"
      fi
    else
      print_error_message "No Java installations found in /usr/lib/jvm"
    fi
  fi
}


#= Yay/Pacman commands

#== System update
update_system() {
  yay -Sy "$@"
}


#== System upgrade
upgrade_system() {
  yay -Syu "$@"
}


#= Zen Browser profile

#== Export workspaces, pins & bookmark assignments
zen_export() {
  local ZEN_CONFIG_DIR="$HOME/.zen"
  local CONFIG_FILE="$HOME/zen-profile-config.json"

  if ! command -v sqlite3 &>/dev/null; then
    print_error_message "sqlite3 is required but not installed"
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    print_error_message "jq is required but not installed"
    return 1
  fi

  local profile_dir
  profile_dir=$(find "$ZEN_CONFIG_DIR" -maxdepth 1 -type d -name "*release*" 2>/dev/null | head -n 1)
  if [ -z "$profile_dir" ]; then
    print_error_message "No release profile directory found in $ZEN_CONFIG_DIR"
    return 1
  fi

  local db_path="$profile_dir/places.sqlite"
  if [ ! -f "$db_path" ]; then
    print_error_message "$db_path not found"
    return 1
  fi

  # Copy DB to avoid lock issues while browser is running
  local tmp_db
  tmp_db=$(mktemp /tmp/zen_places_XXXXXX.sqlite)
  cp "$db_path" "$tmp_db"
  [ -f "${db_path}-wal" ] && cp "${db_path}-wal" "${tmp_db}-wal"
  [ -f "${db_path}-shm" ] && cp "${db_path}-shm" "${tmp_db}-shm"

  echo ":: Profile: $profile_dir"

  local workspaces pins bookmark_workspaces
  workspaces=$(sqlite3 -json "$tmp_db" "
    SELECT name, icon, container_id, position, theme_type, theme_colors,
           theme_opacity, theme_rotation, theme_texture
    FROM zen_workspaces ORDER BY position;
  ")
  pins=$(sqlite3 -json "$tmp_db" "
    SELECT p.title, p.url, w.name AS workspace_name, p.position,
           p.is_essential, p.is_group, p.edited_title, p.container_id,
           p.is_folder_collapsed, p.folder_icon,
           parent.title AS folder_parent_title
    FROM zen_pins p
    LEFT JOIN zen_workspaces w ON p.workspace_uuid = w.uuid
    LEFT JOIN zen_pins parent ON p.folder_parent_uuid = parent.uuid
    ORDER BY w.name, p.position;
  ")
  bookmark_workspaces=$(sqlite3 -json "$tmp_db" "
    SELECT b.title AS bookmark_title, pl.url AS bookmark_url,
           w.name AS workspace_name
    FROM zen_bookmarks_workspaces zbw
    JOIN moz_bookmarks b ON zbw.bookmark_guid = b.guid
    JOIN moz_places pl ON b.fk = pl.id
    JOIN zen_workspaces w ON zbw.workspace_uuid = w.uuid
    ORDER BY w.name, b.title;
  ")

  [ -z "$workspaces" ] && workspaces="[]"
  [ -z "$pins" ] && pins="[]"
  [ -z "$bookmark_workspaces" ] && bookmark_workspaces="[]"

  jq -n \
    --argjson workspaces "$workspaces" \
    --argjson pins "$pins" \
    --argjson bookmark_workspaces "$bookmark_workspaces" \
    --arg exported_at "$(date -Iseconds)" \
    '{
      "_comment": "Auto-generated by zen_export — DO NOT EDIT MANUALLY",
      "exported_at": $exported_at,
      "workspaces": $workspaces,
      "pins": $pins,
      "bookmark_workspace_assignments": $bookmark_workspaces
    }' > "$CONFIG_FILE"

  rm -f "$tmp_db" "${tmp_db}-wal" "${tmp_db}-shm"

  local ws_count pin_count bw_count
  ws_count=$(jq '.workspaces | length' "$CONFIG_FILE")
  pin_count=$(jq '.pins | length' "$CONFIG_FILE")
  bw_count=$(jq '.bookmark_workspace_assignments | length' "$CONFIG_FILE")

  print_success_message "Exported to $CONFIG_FILE
  Workspaces: $ws_count
  Pins: $pin_count
  Bookmark assignments: $bw_count"
}


#== Import workspaces, pins & bookmark assignments
zen_import() {
  local CONFIG_FILE="$HOME/zen-profile-config.json"
  local ZEN_CONFIG_DIR="$HOME/.zen"

  if ! command -v sqlite3 &>/dev/null || ! command -v jq &>/dev/null; then
    print_error_message "sqlite3 and jq are required"
    return 1
  fi

  # Look for config file, ask for path if not found
  if [ ! -f "$CONFIG_FILE" ]; then
    echo ":: Config not found at $CONFIG_FILE"
    if $HAS_GUM; then
      CONFIG_FILE=$(gum file --all "$HOME" < /dev/tty)
    else
      read -p "Path to zen-profile-config.json: " CONFIG_FILE
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
      print_error_message "Config file not found: $CONFIG_FILE"
      return 1
    fi
  fi

  # Check browser is closed
  if pgrep -f "zen-browser" &>/dev/null || pgrep -x "zen" &>/dev/null; then
    print_error_message "Zen Browser is running. Please close it first."
    return 1
  fi

  local profile_dir
  profile_dir=$(find "$ZEN_CONFIG_DIR" -maxdepth 1 -type d -name "*release*" 2>/dev/null | head -n 1)
  if [ -z "$profile_dir" ]; then
    print_error_message "No release profile found in $ZEN_CONFIG_DIR"
    return 1
  fi

  local db="$profile_dir/places.sqlite"
  local now=$(($(date +%s) * 1000))

  echo ":: Profile: $profile_dir"
  echo ":: Config:  $CONFIG_FILE"
  echo ""

  # ------ Import workspaces ------
  local ws_count
  ws_count=$(jq '.workspaces | length' "$CONFIG_FILE")
  echo ":: Importing $ws_count workspaces..."

  for i in $(seq 0 $((ws_count - 1))); do
    local name icon position theme_type theme_colors theme_opacity theme_rotation theme_texture container_id
    name=$(jq -r ".workspaces[$i].name" "$CONFIG_FILE")
    icon=$(jq -r ".workspaces[$i].icon // empty" "$CONFIG_FILE")
    position=$(jq -r ".workspaces[$i].position" "$CONFIG_FILE")
    theme_type=$(jq -r ".workspaces[$i].theme_type // \"gradient\"" "$CONFIG_FILE")
    theme_colors=$(jq -r ".workspaces[$i].theme_colors // \"[]\"" "$CONFIG_FILE")
    theme_opacity=$(jq -r ".workspaces[$i].theme_opacity // 0.5" "$CONFIG_FILE")
    theme_rotation=$(jq -r ".workspaces[$i].theme_rotation // empty" "$CONFIG_FILE")
    theme_texture=$(jq -r ".workspaces[$i].theme_texture // empty" "$CONFIG_FILE")
    container_id=$(jq -r ".workspaces[$i].container_id // empty" "$CONFIG_FILE")

    local existing
    existing=$(sqlite3 "$db" "SELECT uuid FROM zen_workspaces WHERE name = '$(echo "$name" | sed "s/'/''/g")' LIMIT 1;")
    if [ -n "$existing" ]; then
      echo "   ⏭️  '$name' already exists"
      continue
    fi

    local uuid
    uuid="{$(cat /proc/sys/kernel/random/uuid)}"

    sqlite3 "$db" "
      INSERT INTO zen_workspaces (uuid, name, icon, container_id, position, created_at, updated_at, theme_type, theme_colors, theme_opacity, theme_rotation, theme_texture)
      VALUES (
        '$uuid',
        '$(echo "$name" | sed "s/'/''/g")',
        $([ -n "$icon" ] && echo "'$(echo "$icon" | sed "s/'/''/g")'" || echo "NULL"),
        $([ -n "$container_id" ] && echo "$container_id" || echo "NULL"),
        $position, $now, $now,
        '$theme_type',
        '$(echo "$theme_colors" | sed "s/'/''/g")',
        $theme_opacity,
        $([ -n "$theme_rotation" ] && echo "$theme_rotation" || echo "NULL"),
        $([ -n "$theme_texture" ] && echo "$theme_texture" || echo "NULL")
      );
    "
    sqlite3 "$db" "INSERT OR REPLACE INTO zen_workspaces_changes (uuid, timestamp) VALUES ('$uuid', $(date +%s));"
    echo "   ✅ '$name'"
  done

  echo ""

  # ------ Import pins (2-pass: folders first, then items) ------
  local pin_count
  pin_count=$(jq '.pins | length' "$CONFIG_FILE")
  echo ":: Importing $pin_count pins..."

  declare -A folder_uuid_map

  # Pass 1: folders
  for i in $(seq 0 $((pin_count - 1))); do
    local is_group
    is_group=$(jq -r ".pins[$i].is_group" "$CONFIG_FILE")
    [ "$is_group" != "1" ] && continue

    local title workspace_name position is_essential edited_title is_folder_collapsed
    title=$(jq -r ".pins[$i].title" "$CONFIG_FILE")
    workspace_name=$(jq -r ".pins[$i].workspace_name // empty" "$CONFIG_FILE")
    position=$(jq -r ".pins[$i].position" "$CONFIG_FILE")
    is_essential=$(jq -r ".pins[$i].is_essential" "$CONFIG_FILE")
    edited_title=$(jq -r ".pins[$i].edited_title // 0" "$CONFIG_FILE")
    is_folder_collapsed=$(jq -r ".pins[$i].is_folder_collapsed // 0" "$CONFIG_FILE")

    local ws_uuid=""
    if [ -n "$workspace_name" ]; then
      ws_uuid=$(sqlite3 "$db" "SELECT uuid FROM zen_workspaces WHERE name = '$(echo "$workspace_name" | sed "s/'/''/g")' LIMIT 1;")
      if [ -z "$ws_uuid" ]; then
        echo "   ⚠️  Workspace '$workspace_name' not found for folder '$title'"
        continue
      fi
    fi

    local existing
    existing=$(sqlite3 "$db" "SELECT uuid FROM zen_pins WHERE title = '$(echo "$title" | sed "s/'/''/g")' AND is_group = 1 AND workspace_uuid = '$ws_uuid' LIMIT 1;")
    if [ -n "$existing" ]; then
      folder_uuid_map["$workspace_name|$title"]="$existing"
      echo "   ⏭️  Folder '$title' (${workspace_name})"
      continue
    fi

    local uuid="{$(cat /proc/sys/kernel/random/uuid)}"
    folder_uuid_map["$workspace_name|$title"]="$uuid"

    sqlite3 "$db" "
      INSERT INTO zen_pins (uuid, title, url, container_id, workspace_uuid, position, is_essential, is_group, created_at, updated_at, edited_title, is_folder_collapsed, folder_icon, folder_parent_uuid)
      VALUES ('$uuid', '$(echo "$title" | sed "s/'/''/g")', '', NULL, $([ -n "$ws_uuid" ] && echo "'$ws_uuid'" || echo "NULL"), $position, $is_essential, 1, $now, $now, $edited_title, $is_folder_collapsed, NULL, NULL);
    "
    sqlite3 "$db" "INSERT OR REPLACE INTO zen_pins_changes (uuid, timestamp) VALUES ('$uuid', $(date +%s));"
    echo "   ✅ Folder '$title' (${workspace_name})"
  done

  # Pass 2: regular pins
  for i in $(seq 0 $((pin_count - 1))); do
    local is_group
    is_group=$(jq -r ".pins[$i].is_group" "$CONFIG_FILE")
    [ "$is_group" = "1" ] && continue

    local title url workspace_name position is_essential edited_title folder_parent_title container_id
    title=$(jq -r ".pins[$i].title" "$CONFIG_FILE")
    url=$(jq -r ".pins[$i].url // empty" "$CONFIG_FILE")
    workspace_name=$(jq -r ".pins[$i].workspace_name // empty" "$CONFIG_FILE")
    position=$(jq -r ".pins[$i].position" "$CONFIG_FILE")
    is_essential=$(jq -r ".pins[$i].is_essential" "$CONFIG_FILE")
    edited_title=$(jq -r ".pins[$i].edited_title // 0" "$CONFIG_FILE")
    folder_parent_title=$(jq -r ".pins[$i].folder_parent_title // empty" "$CONFIG_FILE")
    container_id=$(jq -r ".pins[$i].container_id // empty" "$CONFIG_FILE")

    local ws_uuid=""
    if [ -n "$workspace_name" ]; then
      ws_uuid=$(sqlite3 "$db" "SELECT uuid FROM zen_workspaces WHERE name = '$(echo "$workspace_name" | sed "s/'/''/g")' LIMIT 1;")
      if [ -z "$ws_uuid" ]; then
        echo "   ⚠️  Workspace '$workspace_name' not found for '$title'"
        continue
      fi
    fi

    local folder_parent_uuid=""
    if [ -n "$folder_parent_title" ]; then
      folder_parent_uuid="${folder_uuid_map["$workspace_name|$folder_parent_title"]:-}"
      if [ -z "$folder_parent_uuid" ]; then
        folder_parent_uuid=$(sqlite3 "$db" "SELECT uuid FROM zen_pins WHERE title = '$(echo "$folder_parent_title" | sed "s/'/''/g")' AND is_group = 1 AND workspace_uuid = '$ws_uuid' LIMIT 1;")
      fi
    fi

    if [ -n "$url" ]; then
      local existing
      existing=$(sqlite3 "$db" "SELECT uuid FROM zen_pins WHERE url = '$(echo "$url" | sed "s/'/''/g")' AND workspace_uuid = '$ws_uuid' LIMIT 1;")
      if [ -n "$existing" ]; then
        echo "   ⏭️  '$title' (${workspace_name})"
        continue
      fi
    fi

    local uuid="{$(cat /proc/sys/kernel/random/uuid)}"

    sqlite3 "$db" "
      INSERT INTO zen_pins (uuid, title, url, container_id, workspace_uuid, position, is_essential, is_group, created_at, updated_at, edited_title, is_folder_collapsed, folder_icon, folder_parent_uuid)
      VALUES ('$uuid', '$(echo "$title" | sed "s/'/''/g")', '$(echo "$url" | sed "s/'/''/g")', $([ -n "$container_id" ] && echo "$container_id" || echo "NULL"), $([ -n "$ws_uuid" ] && echo "'$ws_uuid'" || echo "NULL"), $position, $is_essential, 0, $now, $now, $edited_title, 0, NULL, $([ -n "$folder_parent_uuid" ] && echo "'$folder_parent_uuid'" || echo "NULL"));
    "
    sqlite3 "$db" "INSERT OR REPLACE INTO zen_pins_changes (uuid, timestamp) VALUES ('$uuid', $(date +%s));"
    echo "   ✅ '$title' (${workspace_name})"
  done

  echo ""

  # ------ Import bookmark-workspace assignments ------
  local bw_count
  bw_count=$(jq '.bookmark_workspace_assignments | length' "$CONFIG_FILE")
  echo ":: Importing $bw_count bookmark-workspace assignments..."

  for i in $(seq 0 $((bw_count - 1))); do
    local bookmark_title bookmark_url workspace_name
    bookmark_title=$(jq -r ".bookmark_workspace_assignments[$i].bookmark_title" "$CONFIG_FILE")
    bookmark_url=$(jq -r ".bookmark_workspace_assignments[$i].bookmark_url" "$CONFIG_FILE")
    workspace_name=$(jq -r ".bookmark_workspace_assignments[$i].workspace_name" "$CONFIG_FILE")

    local ws_uuid
    ws_uuid=$(sqlite3 "$db" "SELECT uuid FROM zen_workspaces WHERE name = '$(echo "$workspace_name" | sed "s/'/''/g")' LIMIT 1;")
    if [ -z "$ws_uuid" ]; then
      echo "   ⚠️  Workspace '$workspace_name' not found for '$bookmark_title'"
      continue
    fi

    local bookmark_guid
    bookmark_guid=$(sqlite3 "$db" "SELECT b.guid FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id WHERE p.url = '$(echo "$bookmark_url" | sed "s/'/''/g")' LIMIT 1;")
    if [ -z "$bookmark_guid" ]; then
      echo "   ⚠️  Bookmark not found: '$bookmark_title'"
      continue
    fi

    local existing
    existing=$(sqlite3 "$db" "SELECT id FROM zen_bookmarks_workspaces WHERE bookmark_guid = '$bookmark_guid' AND workspace_uuid = '$ws_uuid' LIMIT 1;")
    if [ -n "$existing" ]; then
      echo "   ⏭️  '$bookmark_title' → '$workspace_name'"
      continue
    fi

    sqlite3 "$db" "INSERT INTO zen_bookmarks_workspaces (bookmark_guid, workspace_uuid, created_at, updated_at) VALUES ('$bookmark_guid', '$ws_uuid', $now, $now);"
    sqlite3 "$db" "INSERT OR REPLACE INTO zen_bookmarks_workspaces_changes (bookmark_guid, workspace_uuid, change_type, timestamp) VALUES ('$bookmark_guid', '$ws_uuid', 'added', $(date +%s));"
    echo "   ✅ '$bookmark_title' → '$workspace_name'"
  done

  echo ""
  print_success_message "Import complete!"
}