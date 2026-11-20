#!/bin/bash
#
# matugen post_hook (matugen/config.toml): builds the Zed theme "DankShell Soft"
# (~/.config/zed/themes/dank-soft.json) from DMS's "DankShell Dark": the
# surfaces a step up from near-black, text a little dimmer than white, and the
# syntax in the wallpaper's colors (DMS's uses its terminal palette, which the
# wallpaper hardly moves). DMS's own file stays as it is.
#
#   zed-soften.sh <roles.json>    (matugen/templates/zed-soften.json, rendered)
#
# DMS writes its theme in the same matugen run, before or after this hook: wait
# up to 10 s for one written in this run (within 5 s of the roles file).

roles=$1 dir="$HOME/.config/zed/themes"
dms="$dir/dank-zed-theme.json" out="$dir/dank-soft.json"
[ -s "$roles" ] || exit 0
for _ in $(seq 100); do
  [ -s "$dms" ] && [ "$(stat -c %Y "$dms")" -ge $(($(stat -c %Y "$roles") - 5)) ] && break
  sleep 0.1
done
[ -s "$dms" ] || exit 0

tmp=$(mktemp -p "$dir") || exit 1
if jq --slurpfile r "$roles" '
  $r[0] as $c
  | def set($keys; $color): reduce $keys[] as $k (.; .[$k] = $color);
  def syntax_role:
    if test("^comment") then $c.comment
    elif test("^(keyword|preproc|boolean)") then $c.primary
    elif test("^(function|constructor|emphasis)") then $c.secondary
    elif test("^(string|text\\.literal)") then $c.tertiary
    elif test("^(type|enum|variant|selector)") then $c.primary_fixed
    elif test("^(number|constant|variable\\.special)") then $c.tertiary_fixed
    elif test("^(tag|attribute|label|property|title|link)") then $c.secondary_fixed
    elif test("^(punctuation|operator)") then $c.punct
    elif test("^(variable|embedded)") then $c.text
    else null end;
  .name = "DankShell Soft"
  | .themes = [.themes[] | select(.name == "DankShell Dark") | .name = "DankShell Soft"
    | .style |= (
        set(["editor.background", "editor.gutter.background", "editor.subheader.background",
             "terminal.background", "tab.active_background"]; $c.editor)
        | set(["background", "surface.background", "panel.background", "status_bar.background",
               "title_bar.background", "title_bar.inactive_background", "toolbar.background",
               "tab_bar.background", "tab.inactive_background"]; $c.side)
        | set(["element.background", "editor.active_line.background",
               "editor.highlighted_line.background"]; $c.raised)
        | set(["elevated_surface.background"]; $c.popup)
        | set(["text", "editor.foreground", "terminal.foreground"]; $c.text)
        | set(["text.muted"]; $c.muted)
        | .syntax |= with_entries((.key | syntax_role) as $s | if $s then .value.color = $s else . end)
      )]
' "$dms" >"$tmp" && [ -s "$tmp" ]; then
  chmod 644 "$tmp" && mv -f "$tmp" "$out"
else
  rm -f "$tmp"
fi
