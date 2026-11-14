function delete-env --description 'Delete an environment variable'
    # The bash script can't touch this shell — it writes the fish command here.
    set -l out (mktemp)
    DOTFILES_FISH_OUT=$out bash $HOME/Dotfiles/scripts/functions/delete_env.sh $argv
    source $out
    rm -f $out
end
