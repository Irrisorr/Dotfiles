# fish syntax colors from the wallpaper — DMS runs this template on every
# wallpaper change (matugen/config.toml). fish/conf.d/dms-colors.fish sources it
# at the next prompt of every open shell, over config.fish's static theme.
set --global fish_color_autosuggestion {{colors.outline.default.hex_stripped}}
set --global fish_color_cancel --reverse
set --global fish_color_command {{colors.primary.default.hex_stripped}}
set --global fish_color_comment {{colors.outline.default.hex_stripped}}
set --global fish_color_cwd {{colors.on_primary_container.default.hex_stripped}} --background={{colors.primary_container.default.hex_stripped}} --bold
set --global fish_color_cwd_root {{colors.error.default.hex_stripped}}
set --global fish_color_end {{colors.secondary.default.hex_stripped}}
set --global fish_color_error {{colors.error.default.hex_stripped}}
set --global fish_color_escape {{colors.tertiary.default.hex_stripped}}
set --global fish_color_history_current --bold
set --global fish_color_host normal
set --global fish_color_keyword {{colors.tertiary.default.hex_stripped}}
set --global fish_color_match {{colors.tertiary.default.hex_stripped}}
set --global fish_color_normal {{colors.on_surface.default.hex_stripped}}
set --global fish_color_operator {{colors.tertiary.default.hex_stripped}}
set --global fish_color_option {{colors.on_surface_variant.default.hex_stripped}}
set --global fish_color_param {{colors.on_surface.default.hex_stripped}}
set --global fish_color_quote {{colors.secondary.default.hex_stripped}}
set --global fish_color_redirection {{colors.tertiary.default.hex_stripped}}
set --global fish_color_search_match --background={{colors.secondary_container.default.hex_stripped}}
set --global fish_color_selection --background={{colors.secondary_container.default.hex_stripped}}
set --global fish_color_status {{colors.error.default.hex_stripped}}
set --global fish_color_user {{colors.secondary.default.hex_stripped}}
set --global fish_color_valid_path --underline
set --global fish_pager_color_completion {{colors.on_surface.default.hex_stripped}}
set --global fish_pager_color_description {{colors.on_surface_variant.default.hex_stripped}}
set --global fish_pager_color_prefix {{colors.primary.default.hex_stripped}} --bold --underline
set --global fish_pager_color_progress {{colors.on_primary.default.hex_stripped}} --background={{colors.primary.default.hex_stripped}}
set --global fish_pager_color_selected_background --background={{colors.secondary_container.default.hex_stripped}}
