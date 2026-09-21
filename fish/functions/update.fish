function update --wraps='yay -Sy' --description 'Update system packages (sync repositories)'
  bash $HOME/Dotfiles/scripts/functions/yay_pacman.sh update_system $argv
end
