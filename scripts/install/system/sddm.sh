#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: sddm
configure_sddm() {
  # Theme and drop-in directories differ per distro (and /etc/sddm.conf.d does
  # not exist until something creates it), so both are resolved and the target
  # directory is created before copying.
  execute_command "Configure SDDM" \
    "themes=\"\$(sddm_themes_dir)\" && confd=\"\$(sddm_confd_dir)\" \
     && sudo mkdir -p \"\$themes\" \"\$confd\" \
     && sudo cp -r $HOME/Dotfiles/sddm/corners \"\$themes/\" \
     && sudo cp $HOME/Dotfiles/sddm/default.conf \"\$confd/default.conf\" \
     && sudo systemctl enable sddm"
}
