#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: systemd-hwdb
#
# udev hwdb rules from Dotfiles/etc/udev/hwdb.d (keyboard quirks of specific
# hardware). Each rule matches its machine by DMI, so on any other machine it
# is installed but does nothing — the step is the same on every distro.
configure_hwdb() {
  print_styled_message "Keyboard fixes (udev hwdb)"
  confirm_step "install the udev hwdb rules" || return 1

  local src="$DOTFILES_DIR/etc/udev/hwdb.d" f
  local -a rules=()
  mapfile -t rules < <(compgen -G "$src/*.hwdb")
  [ ${#rules[@]} -gt 0 ] || { echo ":: No rules in $src"; return 1; }

  # Copied, not linked: udev reads /etc before /home may be mounted.
  for f in "${rules[@]}"; do
    sudo install -Dm644 "$f" "/etc/udev/hwdb.d/$(basename "$f")" || return 2
    echo ":: $(basename "$f") -> /etc/udev/hwdb.d/"
  done

  # Re-trigger every input device: the rules apply without a reboot.
  sudo systemd-hwdb update \
    && sudo udevadm trigger --subsystem-match=input --action=change \
    || return 2

  # atkbd keys that now get a forced release (the volume keys on the ThinkBook).
  [ -r /sys/bus/serio/devices/serio0/force_release ] \
    && echo ":: force_release: $(cat /sys/bus/serio/devices/serio0/force_release)"
  print_success_message "hwdb rules installed"
}
