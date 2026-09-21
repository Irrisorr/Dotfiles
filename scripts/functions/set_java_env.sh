#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Set JAVA_HOME env var with existing java versions on the system
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
        if [ -d "$CONFIG_DIR/fish" ]; then
          mkdir -p "$CONFIG_DIR/fish"
          if grep -q "set -x JAVA_HOME" "$CONFIG_DIR/fish/config.fish"; then
            sed -i "s|set -x JAVA_HOME .*|set -x JAVA_HOME $selected_java|g" "$CONFIG_DIR/fish/config.fish"
          else
            echo "set -x JAVA_HOME $selected_java" >>"$CONFIG_DIR/fish/config.fish"
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

[ "${BASH_SOURCE[0]}" = "$0" ] && set_java_env "$@"
