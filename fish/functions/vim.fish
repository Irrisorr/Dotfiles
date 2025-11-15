function vim --wraps='niri msg action maximize-column' --wraps='niri msg action maximize-column;nvim' --wraps='niri msg action set-column-width "100%";nvim' --description 'alias vim=niri msg action set-column-width "100%";nvim'
    niri msg action set-column-width "100%";nvim $argv
end
