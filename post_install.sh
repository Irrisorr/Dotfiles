#!/bin/bash

. $HOME/Dotfiles/scripts/lib/common.sh
. "$APPS_DIR/zen.sh"   # for _zen_find_profile + restore_private_zen


#== System Update
system_update


#== Auth github via Github-cli
if command -v gh &>/dev/null; then
  execute_command "Auth github via Github-cli (Browser Required)" "gh auth login"
fi


#== Private Dotfiles (Zen Browser)
print_styled_message "Configuring Private Dotfiles"
if command -v gh &>/dev/null; then
  private_dotfiles_zen="$PRIVATE_DIR/zen-browser"

  if [ ! -d "$PRIVATE_DIR" ]; then
    if confirm_action "clone your private Dotfiles repository (Dotfiles-private)"; then
      echo ":: Cloning via gh cli..."
      gh repo clone Irrisorr/Dotfiles-private "$PRIVATE_DIR" < /dev/tty
    fi
  elif [ -d "$PRIVATE_DIR/.git" ]; then
    # Already cloned — pull so files updated on GitHub are not stale locally.
    if confirm_action "pull the latest changes in Dotfiles-private"; then
      echo ":: Pulling latest private Dotfiles..."
      git -C "$PRIVATE_DIR" pull < /dev/tty
    fi
  fi

  if [ -d "$private_dotfiles_zen" ] \
     && confirm_action "restore private Zen Browser files into your profile"; then
    echo ":: Searching for Zen Browser profile directory..."
    profile_dir=$(_zen_find_profile)
    if [ -n "$profile_dir" ]; then
      echo ":: Restoring private Zen files into $profile_dir"
      restore_private_zen "$profile_dir"
      check_success "Private Zen-Browser Dotfiles restored"
    else
      echo ":: WARNING: Zen Browser release profile not found. Cannot restore private configs."
    fi
  fi
fi


#== iMe Desktop installation
print_styled_message "Installing iMe Desktop"
if confirm_action "install iMe Desktop"; then
  mkdir -p $HOME/Downloads/apps
  cd $HOME/Downloads/apps

  print_styled_message "Downloading iMe Desktop"
  echo ":: Opening browser to download iMe Desktop..."
  xdg-open "https://imem.app/download/desktop/linux"

  print_styled_message "Waiting for download"
  echo ":: Please download the iMe Desktop package from the browser."
  echo ":: After downloading, press Enter to continue..."
  read -p "Press Enter when download is complete: " dummy

  # Find the most recent iMe download
  IME_ARCHIVE=$(find $HOME/Downloads -name "iMe*.tar.xz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

  if [ -z "$IME_ARCHIVE" ]; then
    print_error_message "iMe Desktop archive not found in Downloads folder"
    echo ":: Please download iMe Desktop manually and extract it to $HOME/Downloads/apps/iMeDesktop"
  else
    print_styled_message "Extracting iMe Desktop"
    execute_command tar -xf "$IME_ARCHIVE" -C $HOME/Downloads/apps

    if [ -d $HOME/Downloads/apps/iMeDesktop ]; then
      print_styled_message "Running iMe Desktop to create desktop file"
      echo ":: Starting iMe Desktop, it will be terminated after 2 seconds..."
      cd $HOME/Downloads/apps/iMeDesktop
      ./iMe &
      IME_PID=$!
      sleep 2
      kill $IME_PID 2>/dev/null
      print_success_message "iMe Desktop desktop file created"
    else
      print_error_message "iMe Desktop directory not found after extraction"
    fi
  fi

  cd - >/dev/null
fi


#== RustDesk installation
print_styled_message "Installing RustDesk"
if confirm_action "install RustDesk version 1.3.7"; then
  mkdir -p $HOME/Downloads/apps
  cd $HOME/Downloads/apps

  print_styled_message "Downloading RustDesk 1.3.7"
  RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.3.7/rustdesk-1.3.7-0-x86_64.pkg.tar.zst"
  RUSTDESK_PKG="rustdesk-1.3.7-0-x86_64.pkg.tar.zst"

  execute_script wget -O "$RUSTDESK_PKG" "$RUSTDESK_URL"
  print_styled_message "Installing RustDesk package"
  execute_script sudo pacman -U --noconfirm "$RUSTDESK_PKG"
  print_success_message "RustDesk 1.3.7 installed successfully"
  cd - >/dev/null
fi


#== Hyprland plugins installation
if command -v hyprpm &>/dev/null; then
  print_styled_message "Installing Hyprland plugins"

  # hypr-dynamic-cursors plugin
  print_styled_message "Installing hypr-dynamic-cursors plugin"
  if confirm_action "install hypr-dynamic-cursors plugin"; then
    print_styled_message "Adding hypr-dynamic-cursors plugin"
    execute_command hyprpm add https://github.com/virtcode/hypr-dynamic-cursors

    print_styled_message "Enabling hypr-dynamic-cursors plugin"
    execute_command hyprpm enable dynamic-cursors

    print_success_message "hypr-dynamic-cursors plugin installed and enabled"
  fi
fi


#== Reboot
execute_command "Restart your computer for changes to take effect" "reboot"
