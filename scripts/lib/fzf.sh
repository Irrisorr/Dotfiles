#!/bin/bash
#
# Shared parts of the fzf pickers (install/fzf_picker.sh, install/fzf_config.sh).
# The top part is free of common.sh on purpose: fzf sources this file again on
# every key press. fzf_ready / bootstrap_fzf at the end are for the installer.
#
# Both pickers feed fzf "<key>\t<display>" lines and keep their own state; the
# callbacks fzf runs re-render the list and move the cursor back with pos().
#
# Two modes, like vim: the list starts in LIST mode (input hidden; j/k move,
# Space ticks, Esc leaves). / or Ctrl-F opens SEARCH mode, where every key types
# into the query — Space too; Enter or Esc goes back to the list, filter kept.
# Needs fzf >= 0.59 (--no-input, $FZF_INPUT_STATE); Ubuntu 26.04 has 0.67.


# Keys of the rows fzf currently shows, from "<key>\t<display>" lines on stdin.
# Mirrors --exact with smart case: every space-separated term of $FZF_QUERY must
# be a substring, case-insensitive unless the query has capitals (fzf's ^ $ ! '
# operators are not handled). Only used to locate rows; fzf filters for real.
fzf_visible_keys() {
  awk -F'\t' -v q="$FZF_QUERY" '
    BEGIN { n = split(q, t, " "); ci = (q == tolower(q)) }
    {
      s = $2; gsub(/\033\[[0-9;]*m/, "", s)
      if (ci) s = tolower(s)
      for (i = 1; i <= n; i++) if (index(s, t[i]) == 0) next
      print $1
    }'
}


# Row number of <key> among the visible keys on stdin; 1 when it is not shown.
fzf_pos_of() {
  local n
  n=$(grep -nxF -- "$1" | cut -d: -f1)
  echo "${n:-1}"
}


# fzf_keys <key> <what> ... — one footer line with the keys highlighted.
fzf_keys() {
  local out=""
  while [ $# -gt 1 ]; do
    out+=$'\e[1;33m'"$1"$'\e[0m'" $2     "
    shift 2
  done
  printf '%s' "${out%     }"
}


# fzf_base_opts <list label> <footer> — fills FZF_OPTS with the look, the two
# modes and cycling. The footer (keys + legend, see fzf_keys) stays the same in
# both modes; search mode's own hint is the input label. Callers add their own
# --preview and Space/Tab/Ctrl-A binds; Space must be bound by the caller, it
# is unbound while searching.
fzf_base_opts() {
  local label="$1" footer="$2"
  local to_search="show-input+unbind(j,k,/,space)"
  local to_list="hide-input+rebind(j,k,/,space)"

  FZF_OPTS=(
    --ansi --no-sort --exact --cycle --layout=reverse --height=100%
    --style=full --list-label=" $label " --input-label=" Search — Enter / Esc: back to the list "
    --delimiter='\t' --with-nth=2
    --no-input --prompt='/ ' --pointer='▶' --gutter=' '
    --footer="$footer" --footer-label=" Keys "
    --color='footer-border:yellow,footer-label:yellow:bold'
    --bind='j:down,k:up,ctrl-/:toggle-preview'
    --bind="/:$to_search"
    --bind="ctrl-f:$to_search"
    --bind="esc:transform:[[ \$FZF_INPUT_STATE = enabled ]] && echo '$to_list' || echo abort"
    --bind="enter:transform:[[ \$FZF_INPUT_STATE = enabled ]] && echo '$to_list' || echo accept"
  )
}


# ─── Installer side (needs common.sh) ─────────────────────────────────────────

FZF_MIN_VERSION="0.59"

# fzf is installed and new enough for the pickers; the installer falls back to
# the gum menus otherwise.
fzf_ready() {
  local v major minor
  command -v fzf &>/dev/null || return 1
  v=$(fzf --version 2>/dev/null) || return 1
  IFS=. read -r major minor _ <<< "${v%% *}"
  [ "${major:-0}" -gt 0 ] || [ "${minor:-0}" -ge "${FZF_MIN_VERSION#0.}" ]
}


# Installs fzf if missing; never fatal — without it the gum menus are used.
bootstrap_fzf() {
  fzf_ready && return 0
  command -v fzf &>/dev/null || { echo ":: Installing fzf for the package and config pickers..."; pkg_install fzf; }
  fzf_ready && return 0
  echo ":: fzf >= $FZF_MIN_VERSION is not available — using the plain gum menus" >&2
  return 1
}
