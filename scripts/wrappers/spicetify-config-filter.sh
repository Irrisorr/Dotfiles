#!/bin/bash
#
# Git filter for spicetify/config-xpui.ini (see .gitattributes). spicetify
# writes this machine's values into it: where Spotify and its prefs are (they
# differ per distro, and the prefs path has the user name in it) and [Backup],
# the Spotify version it backed up. clean blanks them, so git keeps one config
# for every machine; smudge puts this machine's values back when git rewrites
# the file (a pull), or spicetify would lose track of its backup. The values
# wait in .git/spicetify-machine.ini: clean saves them there, since the old
# file is already gone when smudge runs.
#
# Extensions installed per machine (Synthesis: scripts/functions/spicetify.sh)
# have their file in .gitignore: clean drops them from the extensions line,
# smudge adds back the ones whose file is on this machine.
#
#   spicetify-config-filter.sh clean|smudge    (stdin → stdout, run by git)
#
# Registered per clone by the installer's Spicetify step; a clone without it
# just gets the blank values, which spicetify fills in on its first run.

keys='^(spotify_path|prefs_path|version|with)[[:space:]]*='
saved="$(git rev-parse --git-dir)/spicetify-machine.ini"
local_exts='synthesis-spicetify.js'
ext_dir="$(git rev-parse --show-toplevel)/spicetify/Extensions"

extensions_line() {
  local add='' e
  if [ "$1" = smudge ]; then
    for e in $local_exts; do [ -f "$ext_dir/$e" ] && add+="$e "; done
  fi
  awk -v drop="$local_exts" -v add="$add" '
    BEGIN { n = split(drop, d, " "); for (i = 1; i <= n; i++) skip[d[i]] = 1; na = split(add, a, " ") }
    match($0, /^extensions[[:space:]]*=[[:space:]]*/) {
      val = substr($0, RLENGTH + 1); sub(/[[:space:]]+$/, "", val)
      m = split(val, v, "|"); out = ""
      for (i = 1; i <= m; i++) if (v[i] != "" && !(v[i] in skip)) out = out (out == "" ? "" : "|") v[i]
      for (i = 1; i <= na; i++) out = out (out == "" ? "" : "|") a[i]
      print substr($0, 1, RLENGTH) out; next
    }
    { print }'
}

case $1 in
  clean)
    input=$(cat)
    mine=$(grep -E "$keys" <<<"$input" | grep -Ev '=[[:space:]]*$')
    [ -z "$mine" ] || printf '%s\n' "$mine" >"$saved"
    sed -E "s/($keys).*/\1 /" <<<"$input" | extensions_line clean
    ;;
  smudge)
    [ -s "$saved" ] || { extensions_line smudge; exit; }
    awk -v keys="$keys" -v saved="$saved" '
      BEGIN { while ((getline line < saved) > 0) { k = line; sub(/[[:space:]]*=.*/, "", k); mine[k] = line } }
      { k = $0; sub(/[[:space:]]*=.*/, "", k) }
      $0 ~ keys && k in mine { print mine[k]; next }
      { print }' | extensions_line smudge
    ;;
  *) exit 2 ;;
esac
