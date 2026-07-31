#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Copies live/sensitive files into your private dotfiles repo so they can be
# committed and restored after a crash/reinstall. Mappings live in sync_map.json
# (next to this file) as an array of objects:
#
#   file group  { "dest": "~/Dotfiles-private/zen-browser", "sources": ["a", "b"] }
#   sqlite table { "dest": "...", "sqlite": "~/.../places.sqlite", "table": "name" }
#
# A sqlite entry dumps a single table to <dest>/<table>.sql; restore
# (post_install.sh / configure_zen) imports it back into the live places.sqlite.
#
# Anything that already exists in a dest (a file OR a <table>.sql dump) is offered
# in one selection: every conflict is pre-selected (= will be overwritten);
# UNSELECT the ones you want to keep as-is.
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

# Stage, commit (with a message you type) and push the private repo after a sync.
_sync_commit_push() {
  local repo="$PRIVATE_DIR"

  command -v git &>/dev/null || return 0
  [ -d "$repo/.git" ] || { echo ":: $repo is not a git repo — skipping commit"; return 0; }

  if [ -z "$(git -C "$repo" status --porcelain)" ]; then
    echo ":: Nothing to commit in $repo"
    return 0
  fi

  confirm_action "commit & push the synced changes in $repo" || return 0

  local default_msg msg
  default_msg="sync private files ($(date '+%Y-%m-%d %H:%M'))"
  if $HAS_GUM; then
    msg=$(gum input --value "$default_msg" --placeholder "Commit message" </dev/tty)
  else
    read -rp "Commit message [$default_msg]: " msg
  fi
  [ -z "$msg" ] && msg="$default_msg"

  if git -C "$repo" add . \
     && git -C "$repo" commit -m "$msg" \
     && git -C "$repo" push; then
    print_success_message "Committed & pushed private repo"
  else
    print_error_message "git add/commit/push failed in $repo"
    return 1
  fi
}

sync_private() {
  local sync_map="${1:-$FUNCTIONS_DIR/sync/sync_map.json}"

  if ! command -v jq &>/dev/null; then
    print_error_message "'jq' is not installed — required to read the sync map.
Install it: sudo pacman -S jq"
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

  # sqlite3 is only needed when the map has table (sqlite) entries.
  local have_sqlite3=true
  command -v sqlite3 &>/dev/null || have_sqlite3=false
  if [ "$(jq -r 'any(.[]; has("sqlite"))' "$sync_map")" = "true" ] && ! $have_sqlite3; then
    print_error_message "'sqlite3' is not installed — required to sync database tables.
Install it: sudo pacman -S sqlite
Table entries will be skipped."
  fi

  print_styled_message "Syncing private files
$sync_map"

  local copied=0 skipped=0 failed=0 missing=0
  local i

  # ── 1a. Gather file copy pairs (src -> full dest path) ──────────────────────
  local -a srcs=() dsts=()
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

    shopt -s nullglob
    local matches=("$src_pattern")
    shopt -u nullglob

    if [ ${#matches[@]} -eq 0 ]; then
      echo ":: No match for: $src_pattern"
      missing=$((missing + 1))
      continue
    fi

    local src
    for src in "${matches[@]}"; do
      [ -e "$src" ] || { missing=$((missing + 1)); continue; }
      srcs+=("$src")
      dsts+=("$dst_dir/$(basename "$src")")
    done
  done < <(jq -r '.[] | select(.sources) | .dest as $d | .sources[] | [., $d] | @tsv' "$sync_map")

  # ── 1b. Gather sqlite dump jobs (db -> <dest>/<table>.sql) ──────────────────
  local -a sql_db=() sql_table=() sql_out=()
  if $have_sqlite3; then
    local db_raw table dst_raw2
    while IFS=$'\t' read -r db_raw table dst_raw2; do
      [ -z "$db_raw" ] && continue

      local db_pattern dst_dir2
      db_pattern="$(_sync_expand_home "$db_raw")"
      dst_dir2="$(_sync_expand_home "$dst_raw2")"

      shopt -s nullglob
      local dbmatches=("$db_pattern")
      shopt -u nullglob

      if [ ${#dbmatches[@]} -eq 0 ]; then
        echo ":: No match for db: $db_pattern"
        missing=$((missing + 1))
        continue
      fi

      local db
      for db in "${dbmatches[@]}"; do
        [ -e "$db" ] || { missing=$((missing + 1)); continue; }
        sql_db+=("$db")
        sql_table+=("$table")
        sql_out+=("$dst_dir2/$table.sql")
      done
    done < <(jq -r '.[] | select(.sqlite) | [.sqlite, .table, .dest] | @tsv' "$sync_map")
  fi

  # ── 2. Ask which already-existing destinations to overwrite ─────────────────
  # Files AND table dumps that already exist are all offered in one selection.
  local -a conflicts=()
  for i in "${!dsts[@]}"; do
    [ -e "${dsts[$i]}" ] && conflicts+=("${dsts[$i]}")
  done
  for i in "${!sql_out[@]}"; do
    [ -e "${sql_out[$i]}" ] && conflicts+=("${sql_out[$i]}")
  done

  local -A skip=()   # dest path -> 1 means "keep existing, do not overwrite"
  if [ ${#conflicts[@]} -gt 0 ]; then
    if $HAS_GUM; then
      print_styled_message "These already exist in the destination.
All are selected = they WILL be overwritten.
UNSELECT (space) the ones you want to keep as-is, then Enter."
      local keep_args=("--multi" "--height" "20")
      local c
      for c in "${conflicts[@]}"; do keep_args+=("--selected" "$c"); done

      local chosen
      chosen=$(gum_choose_wrapper "${keep_args[@]}" "${conflicts[@]}")

      local -A overwrite=()
      while IFS= read -r line; do
        [ -n "$line" ] && overwrite["$line"]=1
      done <<< "$chosen"

      for c in "${conflicts[@]}"; do
        [ -n "${overwrite[$c]}" ] || skip["$c"]=1
      done
    else
      local c
      for c in "${conflicts[@]}"; do
        confirm_action "overwrite existing $c" || skip["$c"]=1
      done
    fi
  fi

  # ── 3. Copy files ───────────────────────────────────────────────────────────
  for i in "${!srcs[@]}"; do
    if [ -n "${skip[${dsts[$i]}]}" ]; then
      echo ":: kept (not overwritten): ${dsts[$i]}"
      skipped=$((skipped + 1))
      continue
    fi
    mkdir -p "$(dirname "${dsts[$i]}")"
    if cp -rf "${srcs[$i]}" "$(dirname "${dsts[$i]}")/"; then
      echo ":: ${srcs[$i]} -> ${dsts[$i]}"
      copied=$((copied + 1))
    else
      print_error_message "Failed to copy: ${srcs[$i]}"
      failed=$((failed + 1))
    fi
  done

  # ── 4. sqlite table dumps ───────────────────────────────────────────────────
  for i in "${!sql_db[@]}"; do
    local out="${sql_out[$i]}"
    if [ -n "${skip[$out]}" ]; then
      echo ":: kept (not overwritten): $out"
      skipped=$((skipped + 1))
      continue
    fi
    mkdir -p "$(dirname "$out")"
    # immutable=1: read-only, no locking/WAL — dumps fine even while Zen is open.
    if sqlite3 "file:${sql_db[$i]}?immutable=1" ".dump ${sql_table[$i]}" > "$out" \
       && grep -q "CREATE TABLE" "$out"; then
      echo ":: ${sql_db[$i]} [${sql_table[$i]}] -> $out"
      copied=$((copied + 1))
    else
      print_error_message "Failed to dump table '${sql_table[$i]}' from ${sql_db[$i]}"
      rm -f "$out"
      failed=$((failed + 1))
    fi
  done

  # ── summary ─────────────────────────────────────────────────────────────────
  if [ "$failed" -eq 0 ]; then
    print_success_message "Synced $copied item(s)
$skipped kept, $missing missing"
    _sync_commit_push
  else
    print_error_message "Synced $copied item(s)
$skipped kept, $missing missing, $failed failed"
    return 1
  fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && sync_private "$@"
