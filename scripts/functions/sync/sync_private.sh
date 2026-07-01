#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Copies live/sensitive files into your private dotfiles repo so they can be
# committed and restored after a crash/reinstall. Mappings live in sync_map.json
# (next to this file) as an array of objects, each grouping many sources under
# one dest: { "dest": "~/Dotfiles-private/zen-browser", "sources": ["a", "b"] }.
#
# Usage: sync-private [path/to/sync_map.json]

# Expand a leading ~ to $HOME
_sync_expand_home() {
  case "$1" in
    "~/"*) printf '%s' "$HOME/${1#\~/}" ;;
    "~")   printf '%s' "$HOME" ;;
    *)     printf '%s' "$1" ;;
  esac
}

sync_private() {
  local sync_map="${1:-$FUNCTIONS_DIR/sync/sync_map.json}"

  if ! command -v jq &>/dev/null; then
    print_error_message "jq is required to read $sync_map"
    return 1
  fi

  if [ ! -f "$sync_map" ]; then
    print_error_message "Sync map not found: $sync_map"
    return 1
  fi

  if ! jq empty "$sync_map" 2>/dev/null; then
    print_error_message "Invalid JSON: $sync_map"
    return 1
  fi

  print_styled_message "Syncing private files
$sync_map"

  local copied=0 failed=0 missing=0

  # Read each entry as a tab-separated "source<TAB>dest" line.
  local src_raw dst_raw
  while IFS=$'\t' read -r src_raw dst_raw; do
    [ -z "$src_raw" ] && continue

    if [ -z "$dst_raw" ]; then
      print_error_message "Entry missing 'dest': $src_raw"
      failed=$((failed + 1))
      continue
    fi

    local src_pattern dst_dir
    src_pattern="$(_sync_expand_home "$src_raw")"
    dst_dir="$(_sync_expand_home "$dst_raw")"

    # Glob-expand the source pattern (handles spaces, skips on no match)
    shopt -s nullglob
    local matches=("$src_pattern")
    shopt -u nullglob

    if [ ${#matches[@]} -eq 0 ]; then
      echo ":: No match for: $src_pattern"
      missing=$((missing + 1))
      continue
    fi

    mkdir -p "$dst_dir"

    local src
    for src in "${matches[@]}"; do
      [ -e "$src" ] || { missing=$((missing + 1)); continue; }
      if cp -rf "$src" "$dst_dir/"; then
        echo ":: $src -> $dst_dir/$(basename "$src")"
        copied=$((copied + 1))
      else
        print_error_message "Failed to copy: $src"
        failed=$((failed + 1))
      fi
    done
  done < <(jq -r '.[] | .dest as $d | .sources[] | [., $d] | @tsv' "$sync_map")

  if [ "$failed" -eq 0 ]; then
    print_success_message "Synced $copied file(s)
$missing missing, $failed failed"
  else
    print_error_message "Synced $copied file(s)
$missing missing, $failed failed"
    return 1
  fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && sync_private "$@"
