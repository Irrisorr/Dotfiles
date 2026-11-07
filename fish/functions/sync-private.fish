function sync-private --description 'Back up the files listed in sync_map.json'
    bash $HOME/Dotfiles/scripts/functions/sync/sync.sh map $argv
end
