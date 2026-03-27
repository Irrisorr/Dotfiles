function delete-env --description 'Delete an environment variable'
    bash -c ". $HOME/Dotfiles/scripts/scripts.sh && delete_env $argv"
    if env | grep -q "$argv[1]"
        set -ge $argv[1]
    end
end
