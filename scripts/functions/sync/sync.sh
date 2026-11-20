#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# One entry point for copying live configs back into Dotfiles (live → Dotfiles
# only; the installer does the other direction). Every sync is a module in
# modules/<name>.sh:
#
#   SYNC_TITLE="Zen browser"           shown in the menu
#   SYNC_DESC="what it copies"
#   sync_module() { ... }              does the work; non-zero = failed
#
# A new file there shows up in the menu on its own. Modules run in a subshell,
# so they may define helpers with any names.
#
# Usage: sync.sh               menu (Space ticks several, Enter runs them)
#        sync.sh <name>...     run modules without the menu (sync.sh zen map)

SYNC_DIR="$FUNCTIONS_DIR/sync"


# Modules as "<name>\t<display>".
_sync_entries() {
  local f name title desc
  for f in "$SYNC_DIR"/modules/*.sh; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .sh)
    IFS=$'\t' read -r title desc < <(. "$f"; printf '%s\t%s\n' "$SYNC_TITLE" "$SYNC_DESC")
    printf '%s\t%s  \e[90m%s\e[0m\n' "$name" "${title:-$name}" "$desc"
  done
}


# Picks modules; prints their names, one per line.
_sync_pick() {
  local entries
  entries=$(_sync_entries)
  [ -n "$entries" ] || { print_error_message "No sync modules in $SYNC_DIR/modules" >&2; return 1; }

  if fzf_ready; then
    fzf_base_opts "Sync to Dotfiles" "$(fzf_keys "j/k ↑↓" move Space tick Enter "run ticked (or current)" "/ Ctrl-F" search Esc quit)"
    printf '%s\n' "$entries" | fzf "${FZF_OPTS[@]}" --multi \
      --bind='space:toggle+down,tab:toggle+down' | cut -f1
  else
    local -a labels=() names=()
    local name label chosen i
    while IFS=$'\t' read -r name label; do
      names+=("$name")
      labels+=("$(printf '%s' "$label" | sed 's/\x1b\[[0-9;]*m//g')")
    done <<< "$entries"
    chosen=$(gum_choose_wrapper --multi "${labels[@]}") || return 1
    while IFS= read -r label; do
      for i in "${!labels[@]}"; do
        [ "${labels[$i]}" = "$label" ] && echo "${names[$i]}"
      done
    done <<< "$chosen"
  fi
}


_sync_run() {
  local f="$SYNC_DIR/modules/$1.sh"
  [ -f "$f" ] || { print_error_message "No sync module: $1"; return 1; }
  ( . "$f"; print_styled_message "${SYNC_TITLE:-$1}"; sync_module )
}


sync_main() {
  local -a names=()
  if [ $# -gt 0 ]; then
    names=("$@")
  else
    mapfile -t names < <(_sync_pick)
    [ ${#names[@]} -gt 0 ] || return 0
  fi

  local name failed=0
  for name in "${names[@]}"; do
    _sync_run "$name" || failed=$((failed + 1))
  done

  if git -C "$DOTFILES_DIR" status --porcelain | grep -q .; then
    echo
    echo ":: Changes in $DOTFILES_DIR (commit them yourself):"
    git -C "$DOTFILES_DIR" status --short
  fi
  [ "$failed" -eq 0 ]
}

[ "${BASH_SOURCE[0]}" = "$0" ] && sync_main "$@"
