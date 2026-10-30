#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: sddm
configure_sddm() {
  print_styled_message "Configure SDDM"
  confirm_action "configure SDDM and make it the login screen" || return 1

  # Theme and drop-in dirs differ per distro, and /etc/sddm.conf.d may not exist
  # yet. cp -T copies onto the theme dir instead of nesting a second copy inside
  # it when the theme is already installed.
  local themes confd
  themes=$(sddm_themes_dir)
  confd=$(sddm_confd_dir)
  sudo mkdir -p "$themes" "$confd" \
    && sudo cp -rT "$DOTFILES_DIR/sddm/corners" "$themes/corners" \
    && sudo cp "$DOTFILES_DIR/sddm/default.conf" "$confd/default.conf" \
    || { print_error_message "Failed to install the SDDM theme/config"; return 2; }

  # Debian's sddm.service refuses to start unless it is the default display
  # manager in this file (it is gdm3 on a stock Ubuntu).
  if is_debian; then
    echo /usr/bin/sddm | sudo tee /etc/X11/default-display-manager >/dev/null || return 2
  fi

  # --force takes over the display-manager.service alias held by another login
  # manager (gdm3 on Ubuntu, anything else on Arch); without it enable fails.
  sudo systemctl enable --force sddm.service \
    || { print_error_message "Failed to enable sddm"; return 2; }

  print_success_message "SDDM is the login screen after the next reboot"
  if is_debian; then
    echo ":: To go back to GDM: echo /usr/sbin/gdm3 | sudo tee /etc/X11/default-display-manager && sudo systemctl enable --force gdm3"
  fi
}
