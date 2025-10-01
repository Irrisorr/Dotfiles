#!/bin/bash

# Post-installation tasks
print_styled_message "Post-Installation Tasks"

# iMe Desktop installation
print_styled_message "Installing iMe Desktop"
if confirm_action "install iMe Desktop"; then
  mkdir -p ~/Downloads/apps
  cd ~/Downloads/apps

  print_styled_message "Downloading iMe Desktop"
  echo ":: Opening browser to download iMe Desktop..."
  xdg-open "https://imem.app/download/desktop/linux"

  print_styled_message "Waiting for download"
  echo ":: Please download the iMe Desktop package from the browser."
  echo ":: After downloading, press Enter to continue..."
  read -p "Press Enter when download is complete: " dummy

  # Find the most recent iMe download
  IME_ARCHIVE=$(find ~/Downloads -name "iMe*.tar.xz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

  if [ -z "$IME_ARCHIVE" ]; then
    print_error_message "iMe Desktop archive not found in Downloads folder"
    echo ":: Please download iMe Desktop manually and extract it to ~/Downloads/apps/iMeDesktop"
  else
    print_styled_message "Extracting iMe Desktop"
    execute_command tar -xf "$IME_ARCHIVE" -C ~/Downloads/apps

    if [ -d ~/Downloads/apps/iMeDesktop ]; then
      print_styled_message "Running iMe Desktop to create desktop file"
      echo ":: Starting iMe Desktop, it will be terminated after 2 seconds..."
      cd ~/Downloads/apps/iMeDesktop
      ./iMe &
      IME_PID=$!
      sleep 2
      kill $IME_PID 2>/dev/null
      print_success_message "iMe Desktop desktop file created"
    else
      print_error_message "iMe Desktop directory not found after extraction"
    fi
  fi

  cd - >/dev/null # Return to original directory
fi

#Auth github via Github-cli
print_styled_message "Auth github via Github-cli (Browser required)"
if confirm_action "auth github via Github-cli"; then
  execute_command gh auth login
  print_success_message "Github-cli auth success"
fi

print_styled_message "Post-installation tasks complete!"

