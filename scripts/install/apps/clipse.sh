#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: clipse

configure_clipse_steps=(
  "Config (config.json)|_clipse_config"
  "Expire history on time (systemd timer clipse-prune)|_clipse_prune_timer|systemctl"
)

# About: clipse (Mod+V) config and its history expiring on time.
configure_clipse() {
  print_styled_message "Configuring clipse"
  run_substeps "${configure_clipse_steps[@]}"
}

# About: Links the clipse config: keys, theme, image preview.
_clipse_config() {
  execute_command "Link clipse config" "create_symlink $HOME/Dotfiles/clipse/config.json $HOME/.config/clipse/config.json"
}

# clipse's own deleteAfter is off (see scripts/wrappers/clipse-prune.sh); the
# timer runs the script every 5 min with the age from "pruneAfter".
# About: Deletes clipboard history older than pruneAfter every 5 min, with its images.
_clipse_prune_timer() {
  local u units="$HOME/.config/systemd/user"
  mkdir -p "$units"
  for u in clipse-prune.service clipse-prune.timer; do
    create_symlink "$HOME/Dotfiles/systemd/user/$u" "$units/$u" || return 2
  done
  execute_command "Enable clipse-prune.timer" \
    "systemctl --user daemon-reload && systemctl --user enable --now clipse-prune.timer"
}
