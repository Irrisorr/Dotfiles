# Install gum for better output styling
if ! command -v gum &>/dev/null; then
  echo ":: Installing gum for beautiful output..."
  sudo pacman -S --noconfirm gum || {
    echo ":: Failed to install gum, continuing without it..."
    HAS_GUM=false
  }
else
  HAS_GUM=true
fi


# Universal gum choose wrapper function
gum_choose_wrapper() {
  local mode="single"
  local height=15
  declare -a selected_items=()
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --multi)
        mode="multi"
        shift
        ;;
      --height)
        height="$2"
        shift 2
        ;;
      --selected)
        selected_items+=("$2")
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
  
  local options=("$@")
  local cmd_args=("choose")
  
  if [ "$mode" = "multi" ]; then
    cmd_args+=("--no-limit")
  fi
  
  cmd_args+=("--height" "$height")
  
  for item in "${selected_items[@]}"; do
    cmd_args+=("--selected" "$item")
  done
  
  gum "${cmd_args[@]}" "${options[@]}" </dev/tty
}


# Function to choose only one option from a list using gum (using Enter key)
choose_action() {
  gum choose "$@" </dev/tty
}


# Function to choose multiple options from a list using gum (using Space key and Enter for confirmation)
choose_action_no_limit() {
  gum choose --no-limit --height 20 "$@" </dev/tty
}


# Function to confirm an action with the user (returns 0 for yes, 1 for no)
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


# Function to check the success of the last command and print appropriate message 
check_success() {
  if [ $? -eq 0 ]; then
    print_success_message "$1"
  else
    print_error_message "$1"
    exit 1
  fi
}


# Function to print success messages (green color)
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


# Function to print error messages (red color)
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


# Function to print styled messages using gum (pink color)
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