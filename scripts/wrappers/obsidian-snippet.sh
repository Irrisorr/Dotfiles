#!/bin/bash
#
# matugen post_hook (matugen/config.toml): copies the rendered Obsidian colors
# (matugen/templates/obsidian-colors.css) into every vault Obsidian knows, as
# .obsidian/snippets/dms-colors.css. Obsidian watches that folder and reloads
# an enabled snippet when it changes; configure_obsidian enables it.
#
#   obsidian-snippet.sh <colors.css>

. "$HOME/Dotfiles/scripts/lib/paths.sh"

css=$1
[ -s "$css" ] || exit 0
obsidian_vaults | while IFS= read -r vault; do
  mkdir -p "$vault/.obsidian/snippets" && cp "$css" "$vault/.obsidian/snippets/dms-colors.css"
done
