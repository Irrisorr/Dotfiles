#!/bin/bash
#
# matugen post_hook (matugen/config.toml): makes DMS's VS Code theme easier on
# the eyes. Backgrounds go one step up from DMS's near-black surfaces, text
# takes on_surface_variant instead of near-white, comments take outline (the
# "Dark" variant has them almost at the background color). Patches the "Dark"
# and the default variant; "Light" stays as DMS writes it.
#
#   vscode-soften.sh <roles.json>    (matugen/templates/vscode-soften.json, rendered)
#
# Our output is marked ("dotfilesSoftened"), DMS's isn't. DMS writes its theme
# files in the same matugen run, before or after this hook — so patch as soon
# as a file is unmarked (DMS has written it), and after 10 s anyway (DMS's VS
# Code template off). The patch always starts from DMS's own version, kept in
# ~/.cache/matugen, so a rerun with other roles doesn't stack on the last one.

roles=$1
[ -s "$roles" ] || exit 0
cache=$(dirname "$roles")

patch_theme() {
  local file=$1 variant=$2 tmp
  local dms="$cache/vscode-dms${file//\//_}"
  for _ in $(seq 100); do
    grep -q '"dotfilesSoftened"' "$file" || break
    sleep 0.1
  done
  # DMS's theme files are JSONC with whole-line comments only.
  grep -q '"dotfilesSoftened"' "$file" || sed '/^[[:space:]]*\/\//d' "$file" >"$dms"
  [ -s "$dms" ] || return
  tmp=$(mktemp) || return
  if jq --slurpfile r "$roles" --arg v "$variant" '
    $r[0][$v] as $c
    | def set($keys; $color): reduce $keys[] as $k (.; .[$k] = $color);
    .colors |= (
      set(["editor.background", "editorGroupHeader.tabsBackground",
           "editorStickyScroll.background", "tab.activeBackground",
           "tab.inactiveBackground", "terminal.background",
           "titleBar.activeBackground", "activityBar.background",
           "statusBar.background", "statusBar.noFolderBackground"]; $c.editor)
      | set(["sideBar.background", "panel.background", "input.background",
             "dropdown.background", "quickInput.background",
             "notifications.background", "notificationCenterHeader.background",
             "editorStickyScrollHover.background",
             "statusBarItem.hoverBackground"]; $c.side)
      | set(["breadcrumb.background", "sideBarSectionHeader.background",
             "list.hoverBackground", "list.inactiveSelectionBackground",
             "editorSuggestWidget.background", "statusBarItem.activeBackground",
             "editor.lineHighlightBackground"]; $c.raised)
      | set(["editorHoverWidget.background", "list.focusBackground"]; $c.popup)
      | with_entries(if .value == $c.brightText then .value = $c.text else . end)
    )
    | .tokenColors |= map(
        if .scope == ["comment"] then .settings.foreground = $c.comment
        elif .settings.foreground == $c.brightText then .settings.foreground = $c.text
        else . end)
    | .semanticTokenColors |= with_entries(
        if .key == "comment" then .value.foreground = $c.comment
        elif (.value | type) == "object" and .value.foreground == $c.brightText then .value.foreground = $c.text
        else . end)
    | .dotfilesSoftened = true
  ' "$dms" >"$tmp"; then
    cat "$tmp" >"$file"
  fi
  rm -f "$tmp"
}

for themes in "$HOME"/.vscode/extensions/danklinux.dms-theme-*/themes \
              "$HOME"/.vscode-oss/extensions/danklinux.dms-theme-*/themes; do
  [ -d "$themes" ] || continue
  patch_theme "$themes/dankshell-dark.json" dark &
  patch_theme "$themes/dankshell-default.json" default &
done
wait
