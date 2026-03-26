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
    print_success_message "Set env $var_name=$var_value"
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
      print_success_message "Deleted $var_name"
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
        
        print_success_message "Java environment configured: $selected_java"
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