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
#   spicetify-config-filter.sh clean|smudge    (stdin → stdout, run by git)
#
# Registered per clone by the installer's Spicetify step; a clone without it
# just gets the blank values, which spicetify fills in on its first run.

keys='^(spotify_path|prefs_path|version|with)[[:space:]]*='
saved="$(git rev-parse --git-dir)/spicetify-machine.ini"

case $1 in
  clean)
    input=$(cat)
    mine=$(grep -E "$keys" <<<"$input" | grep -Ev '=[[:space:]]*$')
    [ -z "$mine" ] || printf '%s\n' "$mine" >"$saved"
    sed -E "s/($keys).*/\1 /" <<<"$input"
    ;;
  smudge)
    [ -s "$saved" ] || exec cat
    awk -v keys="$keys" -v saved="$saved" '
      BEGIN { while ((getline line < saved) > 0) { k = line; sub(/[[:space:]]*=.*/, "", k); mine[k] = line } }
      { k = $0; sub(/[[:space:]]*=.*/, "", k) }
      $0 ~ keys && k in mine { print mine[k]; next }
      { print }'
    ;;
  *) exit 2 ;;
esac
