#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: java
configure_java() {
  . "$FUNCTIONS_DIR/set_java_env.sh"
  set_java_env
}
