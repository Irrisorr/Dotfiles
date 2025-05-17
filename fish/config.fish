if status is-interactive
    # Commands to run in interactive sessions can go here
    fastfetch
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Created by `pipx` on 2025-05-15 18:52:29
set PATH $PATH /home/irrisorr/.local/bin

thefuck --alias | source
