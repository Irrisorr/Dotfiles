#!/bin/bash
#
# The `asd` menu: every shell helper in one universal menu (lib/helpers.sh).
#
# Add an alias: write scripts/functions/<name>.sh defining its function, then
# source it below and add a "Label|func[|guard]" line to the menu call.

. "$HOME/Dotfiles/scripts/lib/common.sh"

# Define every helper function. Recurse so a script that needs its own folder
# (e.g. functions/sync/) just works — only *.sh is sourced, anything else (JSON,
# assets) is ignored. Skip this file itself, since it lives here too.
while IFS= read -r f; do
  [ "$(basename "$f")" = "alias_menu.sh" ] && continue
  . "$f"
done < <(find "$FUNCTIONS_DIR" -type f -name '*.sh')

menu "🚪 Exit" \
  "Set env var|set_env|fish" \
  "Delete env var|delete_env|fish" \
  "Set JAVA_HOME|set_java_env" \
  "Rain animation|terminal_rain|terminal-rain" \
  "Rain animation (floating)|terminal_rain_float|terminal-rain" \
  "Nvim launch|nvim_launch|nvim" \
  "Sync private files|sync_private|jq" \
  "Yay/Pacman commands|yay_commands"
