#!/bin/bash

. ../install_scripts/functions.sh
. ../install_scripts/gum_functions.sh


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
        if grep -q "export JAVA_HOME" ~/.bashrc; then
          sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$selected_java|g" ~/.bashrc
        else
          echo "export JAVA_HOME=$selected_java" >>~/.bashrc
        fi
        
        # Configure zshrc
        if grep -q "export JAVA_HOME" ~/.zshrc; then
          sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$selected_java|g" ~/.zshrc
        else
          echo "export JAVA_HOME=$selected_java" >>~/.zshrc
        fi
        
        # Configure fish
        if [ -d ~/.config/fish ]; then
          mkdir -p ~/.config/fish
          if grep -q "set -x JAVA_HOME" ~/.config/fish/config.fish; then
            sed -i "s|set -x JAVA_HOME .*|set -x JAVA_HOME $selected_java|g" ~/.config/fish/config.fish
          else
            echo "set -x JAVA_HOME $selected_java" >>~/.config/fish/config.fish
          fi
        fi
        
        print_success_message "Java environment configured: $selected_java"
      else
        print_error_message "Invalid selection"
      fi
    else
      print_error_message "No Java installations found in /usr/lib/jvm"
    fi
  fi
}