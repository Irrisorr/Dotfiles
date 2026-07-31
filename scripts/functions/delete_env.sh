#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Delete env var
delete_env() {
  local var_name="$1"

  if [ -z "$var_name" ]; then
    if [ -f "$CONFIG_DIR/fish/config.fish" ]; then
      local vars_array=()
      while IFS= read -r v; do
        [ -n "$v" ] && vars_array+=("$v")
      done <<< "$(grep "^set -x " "$CONFIG_DIR/fish/config.fish" | sed 's/^set -x \([^ ]*\) \(.*\)/\1=\2/')"

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

  if [ -f "$CONFIG_DIR/fish/config.fish" ]; then
    if grep -q "set -x $var_name " "$CONFIG_DIR/fish/config.fish"; then
      sed -i "/set -x $var_name /d" "$CONFIG_DIR/fish/config.fish"
      print_success_message "Deleted $var_name env"
      reload_shell_prompt
    else
      print_error_message "'$var_name' env not found"
    fi
  fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && delete_env "$@"


