function upgrade --wraps='yay -Syu' --description 'Upgrade system packages (install updates)'
  bash $HOME/Dotfiles/scripts/functions/yay_pacman.sh upgrade_system $argv
end
