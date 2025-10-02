if ! command -v gum &>/dev/null; then
  echo ":: Installing gum for beautiful output..."
  sudo pacman -S --noconfirm gum || {
    echo ":: Failed to install gum, continuing without it..."
    HAS_GUM=false
  }
else
  HAS_GUM=true
fi

print_styled_message() {
  local message=$1

  if $HAS_GUM; then
    gum style \
      --foreground 212 --border-foreground 212 --border normal \
      --align center --width 50 --margin "0 2" --padding "1 2" \
      "$message"
  else
    echo -e "\e[1;34m==>\e[0m \e[1m$message\e[0m"
  fi
}

print_success_message() {
  local message=$1

  if $HAS_GUM; then
    gum style \
      --foreground 76 --border-foreground 76 --border normal \
      --align center --width 40 --margin "0 2" --padding "0 1" \
      "✓ $message"
  else
    echo -e "\e[1;32m==>\e[0m \e[1mSuccess: $message\e[0m"
  fi
}

print_error_message() {
  local message=$1

  if $HAS_GUM; then
    gum style \
      --foreground 196 --border-foreground 196 --border normal \
      --align center --width 40 --margin "0 2" --padding "0 1" \
      "✗ $message"
  else
    echo -e "\e[1;31m==>\e[0m \e[1mError: $message\e[0m"
  fi
}

check_success() {
  if [ $? -eq 0 ]; then
    print_success_message "$1"
  else
    print_error_message "$1"
    exit 1
  fi
}

execute_command() {
  "$@"
  check_success "Command execution: $*"
}

choose_action() {
  gum choose "$@" </dev/tty
}

choose_action_no_limit() {
  gum choose --no-limit --height 20 "$@" </dev/tty
}

confirm_action() {
  local message=$1
  if $HAS_GUM; then
    if gum confirm "Do you want to $message?" </dev/tty; then
      return 0
    else
      echo ":: Skipping: $message"
      return 1
    fi
  else
    read -p "Do you want to $message? (y/n): " choice
    case "$choice" in
    y | Y) return 0 ;;
    *)
      echo ":: Skipping: $message"
      return 1
      ;;
    esac
  fi
}

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

system_update() {
  print_styled_message "System Update"
  if confirm_action "update the system"; then
    execute_command sudo pacman -Syu --noconfirm
  fi
}

choose_from_file() {
  local category_to_find="$1"
  local package_file="$(pwd)/packages.txt"

  local app_list
  app_list=$(awk -v category="$category_to_find" '
    BEGIN { p=0 }
    /^#/ {
        if (p) { exit }
        gsub(/^#\s*/, "");
        if ($0 == category) { p=1 }
        next
    }
    p { print }
  ' "$package_file")

  if [ -z "$app_list" ]; then
    echo ":: Category '$category_to_find' is empty or not found"
    return
  fi

  local options_array=()
  while IFS= read -r line; do
    options_array+=("$line")
  done <<<"$app_list"

  choose_action_no_limit "${options_array[@]}"
}

process_all_pkg_categories() {
  local package_file="$(pwd)/packages.txt"
  all_categories=$(grep '^#' "$package_file" | sed 's/^#\s*//')

  while IFS= read -r category; do
    print_styled_message "Installing $category"
    if confirm_action "install $category"; then
      packages=$(choose_from_file "$category")
      if [ -n "$packages" ]; then
        execute_command yay -S --noconfirm $(echo "$packages" | sed 's/\s(.*)//' | tr '\n' ' ')
      fi
    fi
    echo ""
  done < <(echo "$all_categories")
}
