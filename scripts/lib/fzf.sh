#!/bin/bash
#
# Shared parts of the fzf pickers (install/fzf_picker.sh, install/fzf_config.sh).
# Free of common.sh on purpose: fzf sources it again on every key press.
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
