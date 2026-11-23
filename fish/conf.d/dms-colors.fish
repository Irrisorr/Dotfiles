# Wallpaper colors for fish and fzf, written by matugen on every wallpaper
# change (matugen/templates/fish-colors.fish, fzf-colors). Open shells source
# the fish file at their next prompt, after config.fish's static theme (what
# stays without it); fzf reads its file on every start. Remove this file to go
# back to the static theme.
status is-interactive; or return

test -f ~/.cache/matugen/fzf-colors; and set -gx FZF_DEFAULT_OPTS_FILE ~/.cache/matugen/fzf-colors

function __dms_fish_colors --on-event fish_prompt
    set -l file ~/.cache/matugen/fish-colors.fish
    set -l mtime (path mtime $file 2>/dev/null); or return
    test "$mtime" = "$__dms_fish_colors_mtime"; and return
    set -g __dms_fish_colors_mtime $mtime
    source $file
end
