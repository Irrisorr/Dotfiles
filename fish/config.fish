if status is-interactive
    # Commands to run in interactive sessions can go here
    fastfetch
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Created by `pipx` on 2025-05-15 18:52:29
set PATH $PATH /home/irrisorr/.local/bin

# Fish theme
set --global fish_color_autosuggestion 4D5566
set --global fish_color_cancel --reverse
set --global fish_color_command 39BAE6
set --global fish_color_comment 626A73
set --global fish_color_cwd 59C2FF
set --global fish_color_cwd_root red
set --global fish_color_end F29668
set --global fish_color_error FF3333
set --global fish_color_escape 95E6CB
set --global fish_color_history_current --bold
set --global fish_color_host normal
set --global fish_color_host_remote
set --global fish_color_keyword
set --global fish_color_match F07178
set --global fish_color_normal B3B1AD
set --global fish_color_operator E6B450
set --global fish_color_option
set --global fish_color_param B3B1AD
set --global fish_color_quote C2D94C
set --global fish_color_redirection FFEE99
set --global fish_color_search_match --background=E6B450
set --global fish_color_selection --background=E6B450
set --global fish_color_status red
set --global fish_color_user brgreen
set --global fish_color_valid_path --underline
set --global fish_pager_color_background
set --global fish_pager_color_completion normal
set --global fish_pager_color_description B3A06D
set --global fish_pager_color_prefix normal --bold --underline
set --global fish_pager_color_progress brwhite --background=cyan
set --global fish_pager_color_secondary_background
set --global fish_pager_color_secondary_completion
set --global fish_pager_color_secondary_description
set --global fish_pager_color_secondary_prefix
set --global fish_pager_color_selected_background --background=E6B450
set --global fish_pager_color_selected_completion
set --global fish_pager_color_selected_description
set --global fish_pager_color_selected_prefix

# Fish key bindings
set --erase --universal fish_key_bindings

# Thefuck
thefuck --alias | source
