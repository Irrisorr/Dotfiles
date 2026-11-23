#!/bin/bash
#
# Installer engine. Sourced by $HOME/Dotfiles/install.sh, which holds the menus.
#
# This file has everything EXCEPT the menus: it sources common.sh, loads every
# config function, defines the core-step functions, and defines run_final_steps.
# The menus (config_menu + the first menu) live in install.sh so adding a new
# configuration only means editing that one file.

# Before common.sh: sourcing it installs gum, and on a fresh or long-idle
# system that already fails on stale package lists / an old keyring.
. "$HOME/Dotfiles/scripts/lib/distro.sh"
# No terminal to ask on → skip, never a silent "yes" to a full upgrade.
reply=n
if { : </dev/tty; } 2>/dev/null; then
  read -rp ":: Update the system before installing (package lists + all updates)? Recommended [Y/n]: " reply </dev/tty
fi
case "$reply" in
  n | N) ;;
  *) pkg_refresh || echo ":: System update failed — installs may fail too" >&2 ;;
esac

. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menus can't run without gum; stop instead of jumping to the final steps.
require_gum "the installer" || exit 1
# The package and config pickers; without it they fall back to gum menus.
bootstrap_fzf

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
  [ -d "$HOME/.config" ] || return 0   # a brand-new user may not have one yet
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

  # The first login opens a terminal with post_install.sh by itself: a user
  # unit that runs scripts/wrappers/post-install-once.sh once and removes
  # itself. Only on this machine, nothing in the dotfiles. The fish hook below
  # is the fallback for a terminal opened before that (or a session that never
  # reaches graphical-session.target).
  local units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$units"
  cat > "$units/dotfiles-post-install.service" << 'EOF'
[Unit]
Description=Open post_install.sh once after the dotfiles installer
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/Dotfiles/scripts/wrappers/post-install-once.sh

[Install]
WantedBy=graphical-session.target
EOF
  systemctl --user daemon-reload &>/dev/null
  systemctl --user enable dotfiles-post-install.service &>/dev/null

  if command -v fish &>/dev/null; then
    mkdir -p "$HOME/.config/fish/conf.d"
    cat > "$HOME/.config/fish/conf.d/post_install_hook.fish" << 'EOF'
# Only in a terminal of the desktop: a login on a text console (a VM's serial
# one) would run it where the steps can't start apps.
if status is-interactive; and set -q WAYLAND_DISPLAY
    if test -x ~/Dotfiles/post_install.sh
        rm -f ~/.config/fish/conf.d/post_install_hook.fish
        systemctl --user disable dotfiles-post-install.service &>/dev/null
        rm -f ~/.config/systemd/user/dotfiles-post-install.service
        bash ~/Dotfiles/post_install.sh
    end
end
EOF
  fi

  if confirm_action "reboot now"; then
    print_success_message "Configuration complete!
Rebooting in a few seconds. After the reboot the changes take effect, and the
post-install script opens in a terminal by itself after the first login."
    sleep 5
    reboot 2>/dev/null || sudo reboot   # a text console (no polkit agent) needs sudo
  else
    print_success_message "Configuration complete!
A reboot is recommended so all changes take effect.
After you reboot, the post-install script opens in a terminal by itself after
the first login."
  fi
}
