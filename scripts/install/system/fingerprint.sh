#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: fprintd-enroll
configure_fingerprint() {
  print_styled_message "Fingerprint Configuration"
  if confirm_action "configure fingerprint authentication"; then
    execute_script sudo systemctl enable fprintd.service
    print_styled_message "Place your finger several times to scan it"
    execute_script fprintd-enroll
    print_styled_message "Place your finger to verify it"
    execute_script fprintd-verify
    print_success_message "Fingerprint service enabled"
  fi
}
