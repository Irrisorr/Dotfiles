#!/bin/bash
#
# Run once, on the first login after the installer, by the user unit
# dotfiles-post-install.service the installer creates (run_final_steps in
# scripts/install/main.sh). Opens post_install.sh in the default terminal and
# removes that unit, so nothing of it stays for later logins.
#
#   post-install-once.sh    (no arguments)

unit=dotfiles-post-install.service
script="$HOME/Dotfiles/post_install.sh"

remove_unit() {
  systemctl --user disable "$unit" &>/dev/null
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$unit"
  systemctl --user daemon-reload &>/dev/null
}

# The terminal defapps put first (xdg-terminals.list), else any we know.
term_cmd() {
  local id t
  id=$(grep -m1 -v '^#' "${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list" 2>/dev/null)
  case "$id" in
    kitty.desktop) t=kitty ;;
    Alacritty.desktop | alacritty.desktop) t=alacritty ;;
    foot.desktop) t=foot ;;
    com.mitchellh.ghostty.desktop) t=ghostty ;;
    org.wezfurlong.wezterm.desktop) t=wezterm ;;
  esac
  for t in $t kitty alacritty foot ghostty wezterm; do
    command -v "$t" &>/dev/null || continue
    case $t in
      wezterm) echo "$t start --" ;;
      *) echo "$t -e" ;;
    esac
    return 0
  done
  return 1
}

[ -f "$script" ] || { remove_unit; exit 0; }
term=$(term_cmd) || exit 0
remove_unit
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/post_install_hook.fish"

# Lets DMS, the portals and the polkit agent come up first.
sleep 3
# Started by the compositor, not as a child of this unit: what post-install
# opens (Obsidian, Spotify, ...) must not belong to a finished oneshot service.
# shellcheck disable=SC2086  # "<terminal> -e" is two words
if [ -n "$NIRI_SOCKET" ] && command -v niri &>/dev/null; then
  niri msg action spawn -- $term bash "$script"
elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl &>/dev/null; then
  hyprctl dispatch exec "$term bash $script" >/dev/null
else
  setsid -f $term bash "$script" >/dev/null 2>&1
fi
