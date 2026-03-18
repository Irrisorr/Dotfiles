#!/bin/bash

. ./gum_functions.sh


declare -A SELECTED_PACKAGES

# Function to handle interactive category selection and package selection
interactive_category_selection() {
  local package_file="$(pwd)/packages.txt"
  
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
    
    print_styled_message "Select Package Categories"
    echo "Navigate with arrows, ENTER to confirm"
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
  local package_file="$(pwd)/packages.txt"
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
  
  print_styled_message "Selecting packages from: $category"
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
  local package_file="$(pwd)/packages.txt"

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
    bash -c ". $(pwd)/gum_functions.sh && . $(pwd)/functions.sh && $script"
    check_success "$message"
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
      git clone https://aur.archlinux.org/yay.git ~/yay
      check_success "Cloning yay repository"

      cd ~/yay
      makepkg -si --noconfirm
      check_success "Installing yay"
      rm -rf yay
      cd $origin_dir
    fi
  else
    print_styled_message "yay is already installed, skipping..."
  fi
}


set_ru_font() {
  local script="grep -q "^FONT=" /etc/vconsole.conf && \
    sudo sed -i "s/^FONT=.*/FONT=cyr-sun16/" /etc/vconsole.conf || \
    echo "FONT=cyr-sun16" | sudo tee -a /etc/vconsole.conf && \
    systemctl restart systemd-vconsole-setup.service"
  execute_command "Add font for cyrillic support" "$script"
}


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

      cat >~/.config/user-dirs.dirs <<EOL
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOL

      mkdir -p ~/Desktop ~/Downloads ~/Templates ~/Public ~/Documents ~/Music ~/Pictures ~/Videos
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
    fi
  fi
}