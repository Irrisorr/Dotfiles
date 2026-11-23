function upgrade --description 'Upgrade system packages (apt/yay + flatpak)'
  bash $HOME/Dotfiles/scripts/functions/system_packages.sh upgrade_system
end
