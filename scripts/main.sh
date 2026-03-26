#!/bin/bash

. $HOME/Dotfiles/install_scripts/functions.sh
. $HOME/Dotfiles/install_scripts/gum_functions.sh
. $HOME/Dotfiles/scripts/scripts.sh

SCRIPTS_FILE="$HOME/Dotfiles/scripts/scripts.sh"


# Show a gum/fallback menu and return the choice
show_menu() {
  local options=("$@")

  if $HAS_GUM; then
    gum_choose_wrapper --height 20 "${options[@]}"
  else
    choose_action "${options[@]}"
  fi
}


# Extract function name from action code block and call it
run_script_action() {
  local action=$1
  local level=$2
  local code=$(get_action_code_by_level "$action" "$level" "$SCRIPTS_FILE")

  if [ -z "$code" ]; then
    print_error_message "Action not found: $action"
    return 1
  fi

  local func_name=$(echo "$code" | head -1 | sed 's/().*//; s/^[[:space:]]*//')

  if [ -n "$func_name" ] && declare -f "$func_name" &>/dev/null; then
    "$func_name"
  else
    eval "$code"
  fi
}


# Main entry — single-action first level menu
main() {
  local options=()
  while IFS= read -r action; do
    [ -z "$action" ] && continue
    options+=("$action")
  done <<< "$(get_first_level_actions "$SCRIPTS_FILE")"

  if [ ${#options[@]} -eq 0 ]; then
    print_error_message "No actions found"
    return 1
  fi

  local choice
  choice=$(show_menu "${options[@]}") || return 0

  # If action has sub-actions → open submenu, otherwise execute directly
  local sub_actions
  sub_actions=$(get_second_level_actions_for "$choice" "$SCRIPTS_FILE")

  if [ -n "$sub_actions" ]; then
    scripts_submenu "$choice"
  else
    run_script_action "$choice" "1"
  fi
}


# Second-level submenu — single action, scoped to parent
scripts_submenu() {
  local parent=$1
  local options=()

  while IFS= read -r action; do
    [ -z "$action" ] && continue

    local cmd=$(get_command_check "$action" "$SCRIPTS_FILE")
    if [ -z "$cmd" ] || command -v "$cmd" &>/dev/null; then
      options+=("$action")
    fi
  done <<< "$(get_second_level_actions_for "$parent" "$SCRIPTS_FILE")"

  if [ ${#options[@]} -eq 0 ]; then
    print_error_message "No available sub-actions for: $parent"
    return 1
  fi

  options+=("⬅️ Back")

  local choice
  choice=$(show_menu "${options[@]}") || return 0

  if [ "$choice" = "⬅️ Back" ]; then
    main
    return
  fi

  run_script_action "$choice" "2"
}


main
