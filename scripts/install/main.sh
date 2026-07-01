#!/bin/bash
#
# Installer engine. Sourced by $HOME/Dotfiles/install.sh, which holds the menus.
#
# This file has everything EXCEPT the menus: it sources common.sh, loads every
# config function, defines the core-step functions, and defines run_final_steps.
# The menus (config_menu + the first menu) live in install.sh so adding a new
# configuration only means editing that one file.

. "$HOME/Dotfiles/scripts/lib/common.sh"

# Load every config function (system first, then apps).
for f in "$SYSTEM_DIR"/*.sh "$APPS_DIR"/*.sh; do
  [ -e "$f" ] && . "$f"
done


# ─── Core step functions ─────────────────────────────────────────────────────

install_yay() {
  if ! command -v yay &>/dev/null; then
    print_styled_message "Installing yay"
    if confirm_action "install yay"; then
      git clone https://aur.archlinux.org/yay.git "$HOME/yay"
      check_success "Cloning yay repository"
      ( cd "$HOME/yay" && makepkg -si --noconfirm )
      check_success "Installing yay"
      rm -rf "$HOME/yay"
    fi
  else
    print_styled_message "yay is already installed, skipping..."
  fi
}

set_cyrillic_font() {
  print_styled_message "Cyrillic console font"
  if confirm_action "set the cyrillic console font (cyr-sun16)"; then
    if grep -q "^FONT=" /etc/vconsole.conf 2>/dev/null; then
      sudo sed -i "s/^FONT=.*/FONT=cyr-sun16/" /etc/vconsole.conf
    else
      echo "FONT=cyr-sun16" | sudo tee -a /etc/vconsole.conf
    fi
    sudo systemctl restart systemd-vconsole-setup.service
    check_success "Cyrillic console font set"
  fi
}

install_window_manager() {
  print_styled_message "Installing Window Manager"
  if confirm_action "install window manager"; then
    local window_manager
    window_manager=$(choose_action hyprland niri)
    execute_script sudo pacman -S --noconfirm "$window_manager"
  fi
}


# ─── Final steps (run by install.sh after the menus) ─────────────────────────

run_final_steps() {
  execute_command "Delete .bak directories from ~/.config" "find $HOME/.config/ -type d -name '*.bak' -delete"

  if command -v fish &>/dev/null; then
    mkdir -p "$HOME/.config/fish/conf.d"
    cat > "$HOME/.config/fish/conf.d/post_install_hook.fish" << 'EOF'
if status is-interactive
    if test -x ~/Dotfiles/post_install.sh
        rm -f ~/.config/fish/conf.d/post_install_hook.fish
        bash ~/Dotfiles/post_install.sh
    end
end
EOF
  fi

  if confirm_action "reboot now"; then
    print_success_message "Configuration complete!
Rebooting in a few seconds. After the reboot the changes take effect, and the
post-install script will run automatically the first time you open a terminal."
    sleep 5
    reboot
  else
    print_success_message "Configuration complete!
A reboot is recommended so all changes take effect.
After you reboot, the post-install script will run automatically the first time
you open a terminal."
  fi
}
