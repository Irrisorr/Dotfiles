function set-env --description 'Set a new environment variable'
    bash -c ". $HOME/Dotfiles/scripts/scripts.sh && set_env $argv"
    set -gx $argv[1] $argv[2]
end
