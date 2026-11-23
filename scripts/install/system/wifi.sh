#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

WIFI_NO_11AX_CONF="iwlwifi-no-11ax.conf"

# Menu guard: test:has_iwlwifi
has_iwlwifi() { [ -d /sys/module/iwlwifi ]; }

# Per machine: only for an Intel Wi-Fi 6/6E card that has to join an AP whose
# firmware drops 802.11ax association requests (etc/modprobe.d/iwlwifi-no-11ax.conf
# says which). The module option applies from the next driver load; reloading it
# here would cut the connection the installer may be using.
# About: Turns 802.11ax off on Intel Wi-Fi (iwlwifi), for an old router that drops Wi-Fi 6 association requests.
configure_wifi_no_11ax() {
  print_styled_message "Wi-Fi: 802.11ax off (iwlwifi)"
  confirm_step "turn 802.11ax off on this machine's Intel Wi-Fi" || return 1

  sudo install -Dm644 "$DOTFILES_DIR/etc/modprobe.d/$WIFI_NO_11AX_CONF" "/etc/modprobe.d/$WIFI_NO_11AX_CONF" || return 2
  # The same option under the name the fix had before it was in the dotfiles.
  sudo rm -f /etc/modprobe.d/iwlwifi-m4a.conf
  echo ":: $WIFI_NO_11AX_CONF -> /etc/modprobe.d/ (takes effect after a reboot)"
  echo ":: Now, without a reboot: sudo nmcli radio wifi off; sudo modprobe -r iwlmvm iwlwifi; sudo modprobe iwlwifi; sudo nmcli radio wifi on"
  echo ":: Check: cat /sys/module/iwlwifi/parameters/disable_11ax  (Y)"
  print_success_message "802.11ax off from the next driver load"
}
