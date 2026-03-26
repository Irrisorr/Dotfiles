function update --wraps='yay -Sy' --description 'Update system packages (sync repositories)'
  bash -c ". $HOME/Dotfiles/scripts/scripts.sh && update_system $argv"
end
