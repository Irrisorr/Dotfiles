#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Puts back what defapps (scripts/functions/default_apps.sh) keeps in
# Dotfiles/defapps: your own extensions, the default apps you chose and the
# terminal order. Defaults of apps not installed here are skipped; the rest of
# ~/.config/mimeapps.list stays.

configure_default_apps_steps=(
  "Your extensions (defapps.xml)|_defapps_types|update-mime-database"
  "Default apps (mimeapps.list)|_defapps_defaults"
  "Default terminal (xdg-terminals.list)|_defapps_terminal"
)

# About: Restores which app opens what: browser, terminal, file manager, images, links like tg://.
configure_default_apps() {
  print_styled_message "Restoring default apps (defapps)"
  run_substeps "${configure_default_apps_steps[@]}"
}

# About: Links our own file types (defapps.xml), so they can have a default app.
_defapps_types() {
  execute_command "Link your extensions" ". $HOME/Dotfiles/scripts/functions/default_apps.sh && da_restore_types"
}

# About: Sets the saved default apps for every app installed here.
_defapps_defaults() {
  execute_command "Set the saved default apps" ". $HOME/Dotfiles/scripts/functions/default_apps.sh && da_restore_defaults"
}

# About: Sets which terminal apps open their terminal windows in.
_defapps_terminal() {
  execute_command "Set the saved terminal order" ". $HOME/Dotfiles/scripts/functions/default_apps.sh && da_restore_terminal"
}
