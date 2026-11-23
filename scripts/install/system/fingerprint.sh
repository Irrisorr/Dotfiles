#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fprintd-enroll
# About: Turns on the fingerprint service and scans your finger for login and sudo.
configure_fingerprint() {
  print_styled_message "Fingerprint Configuration"
  if confirm_step "configure fingerprint authentication"; then
    execute_script sudo systemctl enable fprintd.service
    # A machine without a reader (a VM) would fail enroll and verify.
    if fprintd-list "$USER" 2>&1 | grep -q 'NoSuchDevice\|No devices available'; then
      print_error_message "No fingerprint reader found, skipped"
      return 1
    fi
    print_styled_message "Place your finger several times to scan it"
    execute_script fprintd-enroll
    print_styled_message "Place your finger to verify it"
    execute_script fprintd-verify
    print_success_message "Fingerprint service enabled"
  fi
}
