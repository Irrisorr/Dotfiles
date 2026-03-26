function upgrade --wraps='yay -Syu' --description 'Upgrade system packages (install updates)'
  bash -c ". $HOME/Dotfiles/scripts/scripts.sh && upgrade_system $argv"
end
