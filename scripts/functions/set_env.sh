#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Set new env var
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

  if [ -d "$CONFIG_DIR/fish" ]; then
    mkdir -p "$CONFIG_DIR/fish"
    if grep -q "set -x $var_name" "$CONFIG_DIR/fish/config.fish"; then
      sed -i "s|set -x $var_name .*|set -x $var_name $var_value|g" "$CONFIG_DIR/fish/config.fish"
    else
      echo "set -x $var_name $var_value" >>"$CONFIG_DIR/fish/config.fish"
    fi
    print_success_message "Set $var_name=$var_value env"
    reload_shell_prompt
  fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && set_env "$@"
