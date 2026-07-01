#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: sddm
configure_sddm() {
  execute_command "Configure SDDM" "sudo cp -r $HOME/Dotfiles/sddm/corners /usr/share/sddm/themes/ && sudo cp $HOME/Dotfiles/sddm/default.conf /usr/lib/sddm/sddm.conf.d/default.conf && sudo systemctl enable sddm"
}
