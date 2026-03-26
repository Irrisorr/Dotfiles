function vim --wraps='nvim' --description 'Launch nvim in a maximized column in the ide workspace'
    bash -c ". $HOME/Dotfiles/scripts/scripts.sh && nvim_launch $argv"
end
