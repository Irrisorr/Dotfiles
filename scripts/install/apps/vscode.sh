#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: code
#
# DMS colors VS Code from the wallpaper through its own extension: it rewrites
# the extension's theme files on every matugen run. settings.json itself stays
# untracked (personal and account settings) — only the theme key is set.

VSCODE_DMS_EXTENSION="DankLinux.dms-theme"
VSCODE_DMS_THEME="Dynamic Base16 DankShell"

# About: Installs DMS's theme extension and selects it, so VS Code follows the wallpaper.
configure_vscode() {
  print_styled_message "Configuring VS Code"
  confirm_step "install the DMS theme extension and select it" || return 1

  code --install-extension "$VSCODE_DMS_EXTENSION" || return 2

  local settings
  settings=$(vscode_settings_path)
  mkdir -p "$(dirname "$settings")"
  [ -s "$settings" ] || echo '{}' > "$settings"

  # settings.json may be JSONC (comments, trailing commas) — jq can't read that.
  local tmp
  tmp=$(mktemp)
  if jq --arg t "$VSCODE_DMS_THEME" '."workbench.colorTheme" = $t' "$settings" > "$tmp"; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
    print_error_message "Could not parse $settings — select \"$VSCODE_DMS_THEME\" in VS Code yourself"
    return 2
  fi
  print_success_message "VS Code uses \"$VSCODE_DMS_THEME\""
}
