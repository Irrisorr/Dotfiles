#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: obsidian
#
# Obsidian in the wallpaper colors: matugen/templates/obsidian-colors.css fills
# the AnuPpuccin theme's color hooks and Obsidian's own palette, its post_hook copies it into every vault
# as the snippet dms-colors (scripts/wrappers/obsidian-snippet.sh). This step
# turns the snippet on in every vault Obsidian knows.

configure_obsidian_steps=(
  "Colors from the wallpaper (CSS snippet in every vault)|_obsidian_dms_snippet"
)

# About: Obsidian follows the wallpaper in every vault; Obsidian must be closed.
configure_obsidian() {
  print_styled_message "Configuring Obsidian"
  run_substeps "${configure_obsidian_steps[@]}"
}

# appearance.json is Obsidian's own file: an open Obsidian writes it back over
# the change, so it has to be closed. The snippet file itself comes from the
# last matugen run, if there was one, so it works before the next wallpaper.
# About: Copies and turns on the dms-colors CSS snippet in every vault Obsidian knows.
_obsidian_dms_snippet() {
  local css="$HOME/.cache/matugen/obsidian-colors.css" vault conf tmp n=0
  if pgrep -f 'obsidian/app.asar|md.obsidian.Obsidian' &>/dev/null; then
    print_error_message "Close Obsidian first: it writes its settings back on exit"
    return 2
  fi
  while IFS= read -r vault; do
    [ -s "$css" ] && mkdir -p "$vault/.obsidian/snippets" &&
      cp "$css" "$vault/.obsidian/snippets/dms-colors.css"
    conf="$vault/.obsidian/appearance.json"
    [ -s "$conf" ] || echo '{}' >"$conf"
    tmp=$(mktemp)
    if jq '.enabledCssSnippets = ((.enabledCssSnippets // []) - ["dms-colors"] + ["dms-colors"])' "$conf" >"$tmp"; then
      cat "$tmp" >"$conf"
      n=$((n + 1))
    else
      print_error_message "Could not parse $conf"
    fi
    rm -f "$tmp"
  done < <(obsidian_vaults)
  [ $n -gt 0 ] || { print_error_message "No vaults yet, skipped: open them in Obsidian once, then Post-install → Obsidian (or this step again)"; return 1; }
  print_success_message "dms-colors on in $n vault(s)"
}
