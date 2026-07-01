#!/bin/bash
#
# Generic reusable helpers: the universal menu, execute_*, create_symlink, the
# package selection engine, and system_update. Sourced via common.sh, which
# loads lib/gum.sh first — do not source gum.sh here.
# App/system-specific config logic lives in scripts/install/{system,apps}/, not here.

declare -A SELECTED_PACKAGES
declare -A ACTION_STATUS


# ─── Universal menu ───────────────────────────────────────────────────────────
#
# menu <back_label> <entry>...
#
#   entry = "Label|function"            — run `function` when picked
#           "Label|function|guard_cmd"  — same, but hidden unless guard_cmd exists
#
# Each entry maps a display label (decoupled from the function name) to a
# function. A function may itself call `menu` again to open a submenu — the
# submenu's own back button returns to this one. The <back_label> entry (e.g.
# "⬅ Back", "Continue") is always appended last; picking it returns 0.
# Per-function ✓/✗ status is tracked and shown.
menu() {
  local back_label="$1"; shift
  local entries=("$@")

  while true; do
    local options=() funcs=()

    for e in "${entries[@]}"; do
      local label="${e%%|*}"
      local rest="${e#*|}"
      local func="${rest%%|*}"
      local guard=""
      [ "$rest" != "$func" ] && guard="${rest#*|}"

      # Hide the entry when its guard command is not installed.
      if [ -n "$guard" ] && ! command -v "$guard" &>/dev/null; then
        continue
      fi

      local mark="  "
      [ "${ACTION_STATUS[$func]}" = "✓" ] && mark="✓ "
      [ "${ACTION_STATUS[$func]}" = "✗" ] && mark="✗ "

      options+=("$mark$label")
      funcs+=("$func")
    done

    options+=("$back_label")

    local choice
    if $HAS_GUM; then
      choice=$(gum_choose_wrapper --height 30 "${options[@]}")
    else
      choice=$(choose_action_no_limit "${options[@]}")
    fi

    [ $? -ne 0 ] && continue
    [ "$choice" = "$back_label" ] && return 0

    local i
    for i in "${!funcs[@]}"; do
      if [ "${options[$i]}" = "$choice" ]; then
        "${funcs[$i]}"
        local rc=$?
        if [ $rc -eq 0 ]; then
          ACTION_STATUS[${funcs[$i]}]="✓"
        elif [ $rc -eq 1 ]; then
          ACTION_STATUS[${funcs[$i]}]=""
        else
          ACTION_STATUS[${funcs[$i]}]="✗"
        fi
        break
      fi
    done
  done
}


# Offer to restart fish so env changes written to config.fish take effect.
# A subshell can't mutate the parent shell, so exec replaces it with a fresh one.
reload_shell_prompt() {
  if confirm_action "restart shell session to apply changes"; then
    exec fish
  fi
}


# ─── Package selection engine ─────────────────────────────────────────────────

# Function to handle interactive category selection and package selection
package_category_selection() {
  local package_file="$INSTALL_DIR/packages.txt"

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
  local package_file="$INSTALL_DIR/packages.txt"
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
  local package_file="$INSTALL_DIR/packages.txt"

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


# ─── Execution helpers ────────────────────────────────────────────────────────

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
    bash -c ". $HOME/Dotfiles/scripts/lib/common.sh && $script"
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


# Function to update the system using pacman (reused by install.sh and post_install.sh)
system_update() {
  execute_command "Update the system" 'sudo pacman -Syu --noconfirm'
}
