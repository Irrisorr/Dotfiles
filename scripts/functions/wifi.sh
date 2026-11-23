#!/bin/bash
#
# wifi: the 802.11ax fix for Intel cards (iwlwifi) and the checks that found it.
# An old TP-Link AP (WPA/WPA2 mixed, group TKIP) silently drops association
# requests that carry 802.11ax (HE) capabilities: authentication passes,
# association times out, NetworkManager keeps asking for the password. Wi-Fi 6/6E
# cards (AX211) send them, Wi-Fi 5 cards (AC 9560) don't. The fix is the module
# option in etc/modprobe.d/iwlwifi-no-11ax.conf; it turns 11ax off on every
# network, so remove it once the router runs WPA2-PSK with AES only.

. "$HOME/Dotfiles/scripts/lib/common.sh"

WIFI_CONF_SRC="$DOTFILES_DIR/etc/modprobe.d/iwlwifi-no-11ax.conf"
WIFI_CONF="/etc/modprobe.d/iwlwifi-no-11ax.conf"
# The name the fix had before it was in the dotfiles.
WIFI_CONF_OLD="/etc/modprobe.d/iwlwifi-m4a.conf"
WIFI_PARAM="/sys/module/iwlwifi/parameters/disable_11ax"

# command → package (the same name on Arch and Ubuntu unless noted).
wifi_deps() {
  local -a missing=()
  command -v nmcli &>/dev/null || missing+=("$(is_debian && echo network-manager || echo networkmanager)")
  command -v iw &>/dev/null || missing+=(iw)
  command -v lspci &>/dev/null || missing+=(pciutils)
  command -v modprobe &>/dev/null || missing+=(kmod)
  [ ${#missing[@]} -eq 0 ] && return 0
  echo ":: Installing ${missing[*]}"
  pkg_install "${missing[@]}"
}

wifi_iface() { iw dev 2>/dev/null | awk '/Interface/ { print $2; exit }'; }

wifi_status() {
  local iface
  echo ":: Card: $(lspci 2>/dev/null | grep -iE 'network|wireless' | cut -d: -f3- | sed 's/^ //' | head -1)"
  if [ -d /sys/module/iwlwifi ]; then
    echo ":: Driver: iwlwifi, 802.11ax off: $(cat "$WIFI_PARAM" 2>/dev/null || echo ?)"
  else
    echo ":: Driver: not iwlwifi — the fix does nothing here"
  fi
  if [ -f "$WIFI_CONF" ] || [ -f "$WIFI_CONF_OLD" ]; then
    echo ":: Fix: installed ($( [ -f "$WIFI_CONF" ] && echo "$WIFI_CONF" || echo "$WIFI_CONF_OLD"))"
  else
    echo ":: Fix: not installed"
  fi
  iface=$(wifi_iface)
  [ -n "$iface" ] && { echo ":: $iface:"; iw dev "$iface" link | sed 's/^/   /'; }
}

# Drops the connection for a few seconds.
wifi_reload_driver() {
  echo ":: Reloading iwlwifi (Wi-Fi drops for a few seconds)"
  sudo nmcli radio wifi off
  sudo modprobe -r iwlmvm iwlwifi && sudo modprobe iwlwifi
  local rc=$?
  sudo nmcli radio wifi on
  return $rc
}

wifi_fix() {
  wifi_deps || return 2
  [ -d /sys/module/iwlwifi ] || print_error_message "iwlwifi isn't loaded: the option only matters for Intel cards"
  sudo install -Dm644 "$WIFI_CONF_SRC" "$WIFI_CONF" || return 2
  sudo rm -f "$WIFI_CONF_OLD"
  echo ":: $(basename "$WIFI_CONF") -> /etc/modprobe.d/"
  if [ -d /sys/module/iwlwifi ] && [ "$(cat "$WIFI_PARAM" 2>/dev/null)" != Y ]; then
    if gum confirm "Reload the driver now? (Wi-Fi drops for a few seconds; else it applies after a reboot)" </dev/tty; then
      wifi_reload_driver || { print_error_message "Driver reload failed: reboot instead"; return 2; }
    fi
  fi
  print_success_message "802.11ax off: $(cat "$WIFI_PARAM" 2>/dev/null || echo 'after a reboot')"
}

wifi_unfix() {
  [ -f "$WIFI_CONF" ] || [ -f "$WIFI_CONF_OLD" ] || { echo ":: The fix isn't installed"; return 0; }
  sudo rm -f "$WIFI_CONF" "$WIFI_CONF_OLD" || return 2
  if [ -d /sys/module/iwlwifi ] &&
    gum confirm "Reload the driver now? (Wi-Fi drops for a few seconds; else it applies after a reboot)" </dev/tty; then
    wifi_reload_driver || return 2
  fi
  print_success_message "Fix removed: 802.11ax is back from the next driver load — run the connection test"
}

# A one-off success proves nothing for an intermittent bug: connect in series.
wifi_test() {
  local con runs=8 ok=0 fail=0 i
  wifi_deps || return 2
  con=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == "802-11-wireless" { print $1 }' |
    gum choose --header "Connection to test ($runs connects)" </dev/tty) || return 0
  for i in $(seq 1 $runs); do
    nmcli connection down "$con" &>/dev/null
    sleep 2
    if nmcli --wait 25 connection up "$con" &>/dev/null; then
      ok=$((ok + 1)); echo "run $i: OK"
    else
      fail=$((fail + 1)); echo "run $i: FAIL"
    fi
  done
  echo ":: OK=$ok FAIL=$fail"
  [ $fail -eq 0 ]
}

# No "RX AssocResp" after "associate with" = the AP ignores the association
# request: the problem is before the password check (AP firmware, card capabilities).
wifi_log() {
  journalctl -b -k --no-pager | grep -iE 'wlan[0-9]*: (assoc|authenticat|deauth|RX AssocResp|associated)' | tail -30
  echo ":: No 'RX AssocResp' after 'associate with' → the AP ignores the request; a wrong password fails later, in the 4-way handshake"
}

wifi() {
  require_gum wifi || return 1
  local act
  while true; do
    wifi_status
    act=$(gum choose --header "Wi-Fi" \
      "Fix — 802.11ax off on iwlwifi (for an AP that drops Wi-Fi 6 association)" \
      "Connection test — connect a saved network 8 times in a row" \
      "Log — this boot's association attempts" \
      "Remove the fix — the router runs WPA2-PSK + AES now" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      Fix*) wifi_fix ;;
      "Connection test"*) wifi_test ;;
      Log*) wifi_log ;;
      "Remove the fix"*) wifi_unfix ;;
      *) return 0 ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
