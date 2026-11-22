#!/bin/bash
#
# Expires clipse's history on time (systemd/user/clipse-prune.timer, every
# 5 min). clipse's own deleteAfter (v1.2.1) is off in clipse/config.json: it
# only runs when the history is read, removes by indexes that shift after every
# removal (each run drops about every other expired item, and may hit a pinned
# one) and leaves the items' images in tempDir. The age comes from our own key
# "pruneAfter" (seconds) in the same config; 0 or missing = keep everything.

dir="$HOME/.config/clipse"
conf="$dir/config.json"
[ -s "$conf" ] || exit 0
command -v jq &>/dev/null || exit 0

abs() { case $1 in /*) echo "$1" ;; *) echo "$dir/$1" ;; esac; }
after=$(jq -r '.pruneAfter // 0' "$conf")
history=$(abs "$(jq -r '.historyFile // "clipboard_history.json"' "$conf")")
images=$(abs "$(jq -r '.tempDir // "tmp_files"' "$conf")")
[ -s "$history" ] || exit 0

if [ "$after" -gt 0 ] 2>/dev/null; then
  # "recorded" is local time as "2006-01-02 15:04:05.999999999", so plain
  # string order is time order.
  cutoff=$(date -d "-$after seconds" '+%F %T')
  tmp=$(mktemp "$history.XXXXXX") || exit 1
  if jq -c --arg c "$cutoff" '
      .clipboardHistory |= map(select(.pinned or .recorded >= $c))' "$history" >"$tmp" &&
     ! cmp -s "$tmp" <(jq -c . "$history"); then
    mv -f "$tmp" "$history"
  fi
  rm -f "$tmp"
fi

# Images no item points to any more. A minute old at least: clipse -listen
# saves the image a moment before the item that names it.
[ -d "$images" ] || exit 0
keep=$(jq -r '.clipboardHistory[].filePath // empty | select(. != "null") | sub(".*/"; "")' "$history")
find "$images" -maxdepth 1 -type f -mmin +1 -printf '%f\n' |
  grep -vxF -f <(printf '%s\n' "$keep" | grep .) |
  while IFS= read -r f; do rm -f "$images/$f"; done
