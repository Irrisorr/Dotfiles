#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: java
# About: Sets JAVA_HOME to an installed JDK.
configure_java() {
  . "$FUNCTIONS_DIR/set_java_env.sh"
  set_java_env
}
