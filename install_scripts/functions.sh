#!/bin/bash

. $HOME/Dotfiles/install_scripts/gum_functions.sh


declare -A SELECTED_PACKAGES
declare -A ACTION_STATUS


# Interactive menu for first level actions
menu_first_level() {
  local source_file="${1:-$HOME/Dotfiles/install_scripts/main.sh}"
  local actions
  actions=$(get_first_level_actions "$source_file")
  
  while true; do
    local options=()
    
    while IFS= read -r action; do
      [ -z "$action" ] && continue
      if [ "${ACTION_STATUS[$action]}" = "✓" ]; then
        options+=("✓ $action")
      elif [ "${ACTION_STATUS[$action]}" = "✗" ]; then
        options+=("✗ $action")
      else
        options+=("  $action")
      fi
    done <<< "$actions"
    
    options+=("🚀 Continue to app configuration")
    
    local choice
    if $HAS_GUM; then
      choice=$(gum_choose_wrapper --height 20 "${options[@]}")
    else
      choice=$(choose_action_no_limit "${options[@]}")
    fi
    
    [ $? -ne 0 ] && continue
    
    if [ "$choice" = "🚀 Continue to app configuration" ]; then
      break
    fi
    
    local action=$(echo "$choice" | sed 's/^[✓✗ ]\s*//')
    execute_action_from_file "$action" "1" "$source_file"
  done
}


# Interactive menu for second level actions
menu_second_level() {
  local source_file="${1:-$HOME/Dotfiles/install_scripts/main.sh}"
  local actions
  actions=$(get_second_level_actions "$source_file")
  
  while true; do
    local options=()
    local available_actions=()
    
    while IFS= read -r action; do
      [ -z "$action" ] && continue
      
      local cmd=$(get_command_check "$action" "$source_file")
      local should_show=true
      
      if [ -n "$cmd" ]; then
        command -v "$cmd" &>/dev/null
        if [ $? -ne 0 ]; then
          should_show=false
        fi
      fi
      
      if [ "$should_show" = true ]; then
        available_actions+=("$action")
        if [ "${ACTION_STATUS[$action]}" = "✓" ]; then
          options+=("✓ $action")
        elif [ "${ACTION_STATUS[$action]}" = "✗" ]; then
          options+=("✗ $action")
        else
          options+=("  $action")
        fi
      fi
    done <<< "$actions"
    
    if [ ${#available_actions[@]} -eq 0 ]; then
      echo "No applications to configure"
      break
    fi
    
    options+=("⬅️ Back to main menu")
    options+=("✅ Done (end script wout reboot)")
    
    local choice
    if $HAS_GUM; then
      choice=$(gum_choose_wrapper --height 30 "${options[@]}")
    else
      choice=$(choose_action_no_limit "${options[@]}")
    fi
    
    [ $? -ne 0 ] && continue
    
    if [ "$choice" = "✅ Done (end script)" ]; then
      break
    fi
    
    if [ "$choice" = "⬅️ Back to main menu" ]; then
      return 3
    fi
    
    local action=$(echo "$choice" | sed 's/^[✓✗ ]\s*//')
    execute_action_from_file "$action" "2" "$source_file"
  done
}


# Get all first-level actions (#=)
get_first_level_actions() {
  local source_file="${1:-$HOME/Dotfiles/install_scripts/main.sh}"
  grep '^#= ' "$source_file" | sed 's/^#= //'
}


# Get all second-level actions (#==)
get_second_level_actions() {
  local source_file="${1:-$HOME/Dotfiles/install_scripts/main.sh}"
  grep '^#== ' "$source_file" | sed 's/^#== //'
}


# Get second-level actions that belong to a specific first-level action
get_second_level_actions_for() {
  local parent_action=$1
  local source_file="${2:-$HOME/Dotfiles/install_scripts/main.sh}"
  
  awk -v parent="$parent_action" '
    BEGIN { found=0 }
    /^#= / {
      gsub(/^#= /, "");
      if (found) exit;
      if ($0 == parent) { found=1 }
      next
    }
    found && /^#== / {
      gsub(/^#== /, "");
      print
    }
  ' "$source_file"
}


# Get command check for action (looks at the line after #==)
get_command_check() {
  local action=$1
  local source_file="${2:-$HOME/Dotfiles/install_scripts/main.sh}"
  
  grep -A 1 "^#== $action\$" "$source_file" | grep "if command -v" | sed 's/.*if command -v \([^ ]*\).*/\1/'
}


# Execute action and show result
execute_action_from_file() {
  local action=$1
  local level=$2
  local source_file="${3:-$HOME/Dotfiles/install_scripts/main.sh}"
  
  local code=$(get_action_code_by_level "$action" "$level" "$source_file")
  
  if [ -z "$code" ]; then
    ACTION_STATUS[$action]="✗"
    return 1
  fi
  
  eval "$code"
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    ACTION_STATUS[$action]="✓"
  elif [ $exit_code -eq 1 ]; then
    ACTION_STATUS[$action]=""
  else
    ACTION_STATUS[$action]="✗"
  fi
}


# Get action code from source file
get_action_code_by_level() {
  local action=$1
  local level=$2
  local source_file="${3:-$HOME/Dotfiles/install_scripts/main.sh}"
  local marker=$([ "$level" = "2" ] && echo "^#== " || echo "^#= ")
  
  awk -v marker="$marker" -v action="$action" '
    BEGIN { p=0; found=0 }
    $0 ~ marker action "$" {
      p=1
      found=1
      next
    }
    found && /^#[=]+/ {
      exit
    }
    p {
      print
    }
  ' "$source_file"
}


# Function to handle interactive category selection and package selection
package_category_selection() {
  local package_file="$HOME/Dotfiles/install_scripts/packages.txt"
  
  while true; do
    local categories_array=()
    local category_status=()
    
    while IFS= read -r category; do
      categories_array+=("$category")
      
      if [ -n "${SELECTED_PACKAGES[$category]}" ]; then
        category_status+=("✓ $category")
      else
        category_status+=("  $category")
      fi
    done < <(echo "$(get_all_categories)")
    
    category_status+=("⏭️ Skip Package Installation")
    category_status+=("🚀 Start Installation")
    
    print_styled_message "Package Installation
Select Package Categories
Navigate with arrows, ENTER to confirm"
    echo ""
    
    if $HAS_GUM; then
      local choice
      choice=$(gum_choose_wrapper --height 30 "${category_status[@]}")
      
      if [ $? -ne 0 ]; then
        echo ""
        continue
      fi
      
      if [ "$choice" = "🚀 Start Installation" ]; then
        start_package_installation
        break
      elif [ "$choice" = "⏭️ Skip Package Installation" ]; then
        print_styled_message "Skipping package installation"
        break
      else
        local clean_choice=$(echo "$choice" | sed 's/^[✓ ]\s*//')
        select_packages_for_category "$clean_choice"
      fi
    fi
    echo ""
  done
}


# Function to get all categories from the packages.txt file
get_all_categories() {
  local package_file="$HOME/Dotfiles/install_scripts/packages.txt"
  grep '^#' "$package_file" | sed 's/^#\s*//'
}


# Function to start the installation of selected packages
start_package_installation() {
  local total_packages=0
  
  print_styled_message "Preparing to install selected packages..."
  echo ""
  
  for category in "${!SELECTED_PACKAGES[@]}"; do
    local packages="${SELECTED_PACKAGES[$category]}"
    local count=$(echo "$packages" | wc -l)
    total_packages=$((total_packages + count))
    echo "  • $category: $count packages"
  done
  
  echo ""
  if [ $total_packages -eq 0 ]; then
    print_error_message "No packages selected!"
    return 1
  fi
  
  print_styled_message "Total: $total_packages packages"
  
  if confirm_action "start installation"; then
    for category in "${!SELECTED_PACKAGES[@]}"; do
      print_styled_message "Installing from $category"
      local packages="${SELECTED_PACKAGES[$category]}"
      execute_script yay -S --noconfirm $(echo "$packages" | sed 's/\s(.*)//' | tr '\n' ' ')
    done
    
    print_success_message "All packages installed successfully!"
  fi
}


# Function to handle package selection for a specific category
select_packages_for_category() {
  local category=$1
  
  print_styled_message "Selecting packages from: $category
Navigate with arrows, SPACE to select
ENTER to confirm
ESC or ENTER without selection to cancel"
  echo ""
  
  local app_list
  app_list=$(get_packages_from_category "$category")

  if [ -z "$app_list" ]; then
    print_error_message "Category '$category' is empty or not found"
    return 1
  fi

  local options_array=()
  while IFS= read -r line; do
    options_array+=("$line")
  done <<<"$app_list"
  
  local selected
  
  if $HAS_GUM; then
    if [ -n "${SELECTED_PACKAGES[$category]}" ]; then
      local cmd_args=("--multi" "--height" "15")
      while IFS= read -r pkg; do
        cmd_args+=("--selected" "$pkg")
      done <<<"${SELECTED_PACKAGES[$category]}"
      
      selected=$(gum_choose_wrapper "${cmd_args[@]}" "${options_array[@]}")
    else
      selected=$(gum_choose_wrapper --multi --height 15 "${options_array[@]}")
    fi
  else
    selected=$(choose_action_no_limit "${options_array[@]}")
  fi
  
  local exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    echo ":: Selection cancelled"
    echo ""
    sleep 1
    return 0
  fi
  
  if [ -n "$selected" ]; then
    SELECTED_PACKAGES["$category"]="$selected"
    local pkg_count=$(echo "$selected" | wc -l)
    print_success_message "Saved $pkg_count package(s) for $category"
  else
    unset SELECTED_PACKAGES["$category"]
    echo ":: No packages selected"
  fi
  
  echo ""
  sleep 1
}


# Function to get packages from a specific category in the packages.txt file
get_packages_from_category() {
  local category_to_find="$1"
  local package_file="$HOME/Dotfiles/install_scripts/packages.txt"

  awk -v category="$category_to_find" '
    BEGIN { p=0 }
    /^#/ {
        if (p) { exit }
        gsub(/^#\s*/, "");
        if ($0 == category) { p=1 }
        next
    }
    p { print }
  ' "$package_file"
}


# Function to execute a command and check its success
execute_script() {
  "$@"
  check_success "Command execution: $*"
}


# Funtcion to execute a command with confirmation and check its success
execute_command() {
  local message=$1
  local script=$2

  print_styled_message "$message"
  if confirm_action "$message"; then
    bash -c ". $HOME/Dotfiles/install_scripts/gum_functions.sh && . $HOME/Dotfiles/install_scripts/functions.sh && $script"
    local cmd_exit=$?
    if [ $cmd_exit -eq 1 ]; then
      print_error_message "Failed to $message"
      return 1
    fi
    check_success "$message"
    return $?
  else
    return 1
  fi
}


# Function to create a symbolic link
create_symlink() {
  local source=$1
  local target=$2

  if [ -e "$target" ]; then
    if [ -L "$target" ]; then
      echo ":: Symlink already exists, removing..."
      rm "$target"
    else
      echo ":: File/directory already exists, backing up..."
      mv "$target" "${target}.bak"
    fi
  fi

  mkdir -p "$(dirname "$target")"
  ln -sf "$source" "$target"
  check_success "Created symlink from $source to $target"
}


# Function to update the system using pacman
system_update() {
  execute_command "Update the system" 'sudo pacman -Syu --noconfirm'
}


# Function to install yay if not already installed
install_yay() {
  if ! command -v yay &>/dev/null; then
    print_styled_message "Installing yay"
    if confirm_action "install yay"; then
      origin_dir="$(pwd)"
      git clone https://aur.archlinux.org/yay.git $HOME/yay
      check_success "Cloning yay repository"

      cd $HOME/yay
      makepkg -si --noconfirm
      check_success "Installing yay"
      cd $origin_dir
      rm -rf $HOME/yay
    fi
  else
    print_styled_message "yay is already installed, skipping..."
  fi
}


# Function to set the font for cyrillic support
set_ru_font() {
  local script="grep -q "^FONT=" /etc/vconsole.conf && \
    sudo sed -i "s/^FONT=.*/FONT=cyr-sun16/" /etc/vconsole.conf || \
    echo "FONT=cyr-sun16" | sudo tee -a /etc/vconsole.conf && \
    systemctl restart systemd-vconsole-setup.service"
  execute_command "Add font for cyrillic support" "$script"
}


# Function to convert Russian XDG user directories to English
convert_xdg_dirs_to_english() {
  russian_dirs=("$HOME/Рабочий стол" "$HOME/Загрузки" "$HOME/Шаблоны" "$HOME/Общедоступные" "$HOME/Документы" "$HOME/Музыка" "$HOME/Изображения" "$HOME/Видео")
  russian_exists=false

  for dir in "${russian_dirs[@]}"; do
    if [ -d "$dir" ]; then
      russian_exists=true
      break
    fi
  done

  if [ "$russian_exists" = true ]; then
    print_styled_message "Converting Russian XDG user directories to English"
    if confirm_action "Do you want to convert XDG user directories to English?"; then

      cat >$HOME/.config/user-dirs.dirs <<EOL
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOL

      mkdir -p $HOME/Desktop $HOME/Downloads $HOME/Templates $HOME/Public $HOME/Documents $HOME/Music $HOME/Pictures $HOME/Videos
      mv -n "$HOME/Рабочий стол"/* "$HOME/Desktop" 2>/dev/null || true
      mv -n "$HOME/Загрузки"/* "$HOME/Downloads" 2>/dev/null || true
      mv -n "$HOME/Шаблоны"/* "$HOME/Templates" 2>/dev/null || true
      mv -n "$HOME/Общедоступные"/* "$HOME/Public" 2>/dev/null || true
      mv -n "$HOME/Документы"/* "$HOME/Documents" 2>/dev/null || true
      mv -n "$HOME/Музыка"/* "$HOME/Music" 2>/dev/null || true
      mv -n "$HOME/Изображения"/* "$HOME/Pictures" 2>/dev/null || true
      mv -n "$HOME/Видео"/* "$HOME/Videos" 2>/dev/null || true

      rmdir "$HOME/Рабочий стол" "$HOME/Загрузки" "$HOME/Шаблоны" "$HOME/Общедоступные" \
        "$HOME/Документы" "$HOME/Музыка" "$HOME/Изображения" "$HOME/Видео" 2>/dev/null || true

      check_success "XDG user directories converted to English successfully!"
    else
      return 1
    fi
  else
    print_error_message "There are no Russian XDG user directories to convert"
    return 1
  fi
}