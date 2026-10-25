#!/bin/bash
#
# gum bootstrap + every user-facing print/prompt helper.
# Sourced by lib/common.sh AFTER lib/distro.sh (bootstrap_gum needs pkg_install).
#
# gum is required: menu() and the package picker refuse to run without it. The
# smaller helpers here and in functions/{set_env,delete_env,sync_private}.sh do
# keep a plain-bash `read` fallback behind $HAS_GUM.
#
# DOTFILES_NO_GUM_BOOTSTRAP=1 sources this file without triggering an install.

# HAS_GUM must always hold a literal true/false: `if $HAS_GUM` with an empty
# value expands to a null command, whose status is 0 — an unset HAS_GUM would
# silently read as "gum is here" and every helper would call a missing binary.
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true


# Ubuntu has no gum package. Charm's own apt repository has it, and once the
# repo is added gum upgrades with `apt upgrade` like everything else (a .deb
# from GitHub releases never would). Asks first — this adds a third-party repo.
add_charm_repo() {
  local keyring="/etc/apt/keyrings/charm.gpg"
  local list="/etc/apt/sources.list.d/charm.list"

  command -v curl &>/dev/null || pkg_install curl || return 1
  command -v gpg &>/dev/null || pkg_install gnupg || return 1

  sudo mkdir -p /etc/apt/keyrings || return 1
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o "$keyring" || return 1
  sudo chmod 0644 "$keyring"
  echo "deb [signed-by=$keyring] https://repo.charm.sh/apt/ * *" | sudo tee "$list" >/dev/null || return 1
  pkg_sync
}


_gum_install_apt_repo() {
  echo ":: 'gum' is not in the Ubuntu repos. It can be installed from Charm's"
  echo ":: official apt repository (https://repo.charm.sh/apt) and then updates"
  echo ":: with apt upgrade."
  read -rp ":: Add the repository and install gum? (y/N): " reply </dev/tty
  case "$reply" in y | Y) ;; *) return 1 ;; esac

  add_charm_repo && pkg_install gum
}


bootstrap_gum() {
  if command -v gum &>/dev/null; then
    HAS_GUM=true
    return 0
  fi

  echo ":: Installing gum for beautiful output..."
  pkg_install gum &>/dev/null

  # apt has no 'gum', so on Debian/Ubuntu fall through to Charm's apt repo.
  if ! command -v gum &>/dev/null && is_debian; then
    _gum_install_apt_repo
  fi

  if command -v gum &>/dev/null; then
    HAS_GUM=true
  else
    HAS_GUM=false
    echo ":: Failed to install gum. Menus will not work — install it manually:" >&2
    echo "::   $(pkg_install_hint gum)" >&2
  fi
}


# Hard gate for the paths that cannot run without gum (menu, package picker).
require_gum() {
  $HAS_GUM && return 0
  echo ":: '$1' requires gum, which is not installed." >&2
  echo "::   $(pkg_install_hint gum)" >&2
  return 1
}


[ -n "$DOTFILES_NO_GUM_BOOTSTRAP" ] || bootstrap_gum


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
  gum choose --no-limit "$@" </dev/tty
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
    return 1
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