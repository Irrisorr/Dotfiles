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
    set_console_font cyr-sun16
    check_success "Cyrillic console font set"
  fi
}

# Through install_packages, not pkg_install: on Ubuntu niri needs its PPA.
# No separate confirm — install_packages shows the plan and asks.
install_window_manager() {
  print_styled_message "Installing Window Manager"
  local window_manager
  window_manager=$(choose_action hyprland niri) || return 1
  install_packages "$window_manager"
}


# ─── Final steps (run by install.sh after the menus) ─────────────────────────

# Backups create_symlink left behind: dirs and files, including timestamped
# .bak.<date> ones. find does not follow symlinks, so it never reaches into
# ~/Dotfiles through a linked config dir.
_find_config_backups() {
  find "$HOME/.config" \( -name '*.bak' -o -name '*.bak.[0-9]*' \) -prune "$@"
}

run_final_steps() {
  if [ -n "$(_find_config_backups -print -quit)" ]; then
    echo ":: Backups in ~/.config:"
    _find_config_backups -print | sed 's/^/   /'
    if confirm_action "delete all these backups"; then
      _find_config_backups -exec rm -rf {} +
      check_success "Backups deleted"
    fi
  fi

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
