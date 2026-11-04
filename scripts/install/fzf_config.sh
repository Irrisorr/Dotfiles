#!/bin/bash
#
# fzf configuration menu — PROTOTYPE.
#
#   bash ~/Dotfiles/scripts/install/fzf_config.sh          dry run: nothing changes
#   bash ~/Dotfiles/scripts/install/fzf_config.sh --run    really runs the steps
#
# Steps come from config_menu in install.sh (same labels and guards), grouped
# by where their function lives: scripts/install/system or scripts/install/apps.
# A step with a <func>_steps array (configure_niri, configure_hyprland) unfolds
# its actions under it when ticked, all ticked; only the ticked ones run.
#
# j/k or arrows move (wrapping around), Space ticks, Ctrl-A ticks the cursor's
# group, / or Ctrl-F searches (lib/fzf.sh). Enter asks to run the ticked steps —
# or the one under the cursor when none is — and No goes back to the list.
# Yes runs them one by one with their output on screen (each step's own
# "configure X?" question is skipped, the batch was just confirmed); the list
# then comes back with ✓ / ✗ and the step's output in the preview.
#
# Like fzf_picker.sh, fzf calls this script back for every key press; those
# modes only read the cache in $STATE.

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
CMD="bash $(printf %q "$SELF")"     # works without the exec bit
. "$HOME/Dotfiles/scripts/lib/fzf.sh"

# data.tsv columns: kind  key  group  label  func  file  parent  subs
#   kind: H group header, S step, U action of a step (its parent's func)
#   key:  H:<group>, S:<func>, U:<parent>:<func>
# checked: ticked keys;  status: "<func>\t✓|✗" of the last run;
# log/<func>: output of the last run;  src/<func>: the function's code


# ─── fzf callbacks (cache only, no installer libs) ────────────────────────────

_render() {
  awk -F'\t' '
    BEGIN {
      while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) chk[line] = 1
      while ((getline line < (ENVIRON["STATE"] "/status")) > 0) {
        split(line, s, "\t"); st[s[1]] = s[2]
      }
      G = "\033[32m"; E = "\033[31m"; D = "\033[90m"; B = "\033[1;36m"; R = "\033[0m"
    }
    function mark(f) { return st[f] == "✓" ? "  " G "✓" R : (st[f] == "✗" ? "  " E "✗ failed" R : "") }
    $1 == "H" { printf "%s\t%s%s%s\n", $2, B, $3, R; next }
    $1 == "S" {
      label[$5] = $4
      box = ($2 in chk) ? G "[x]" R : "[ ]"
      subs = $8 > 0 ? "  " D "[+" $8 "]" R : ""
      printf "%s\t  %s %s%s%s  %s· %s%s\n", $2, box, $4, mark($5), subs, D, $3, R
      next
    }
    $1 == "U" {
      if (!(("S:" $7) in chk)) next
      box = ($2 in chk) ? G "[x]" R : "[ ]"
      printf "%s\t      %s└ %s%s %s  %s· %s%s\n", $2, D, R, box, $4, D, label[$7], R
    }
  ' "$STATE/data.tsv"
}


_header() {
  echo "Selected: $(grep -c '^S:' "$STATE/checked") step(s)"
}


_redraw() {
  printf 'reload-sync(%s --render)+pos(%d)+change-header:%s' "$CMD" \
    "$(_render | fzf_visible_keys | fzf_pos_of "$1")" "$(_header)"
}


_tick() {   # a step brings all its actions
  grep -qxF "$1" "$STATE/checked" && return
  echo "$1" >> "$STATE/checked"
  [[ $1 == S:* ]] && awk -F'\t' -v p="${1#S:}" '$1 == "U" && $7 == p { print $2 }' \
    "$STATE/data.tsv" >> "$STATE/checked"
}


_untick() {   # a step takes its actions with it
  local tmp="$STATE/checked.tmp"
  grep -vxF "$1" "$STATE/checked" > "$tmp"
  [[ $1 == S:* ]] && { grep -v "^U:${1#S:}:" "$tmp" > "$tmp.2"; mv "$tmp.2" "$tmp"; }
  mv "$tmp" "$STATE/checked"
}


_toggle() {
  case "$1" in
    H:*) ;;
    *) if grep -qxF "$1" "$STATE/checked"; then _untick "$1"; else _tick "$1"; fi ;;
  esac
  _redraw "$1"
}


# Ctrl-A: the visible steps of the cursor's group. All ticked → untick them.
_toggle_group() {
  local key="$1" group k all=1
  local -a keys=()
  group=$(awk -F'\t' -v k="$key" '$2 == k { print $3; exit }' "$STATE/data.tsv")
  mapfile -t keys < <(awk -F'\t' -v g="$group" '
    FILENAME != ARGV[2] { shown[$0] = 1; next }
    $1 == "S" && $3 == g && ($2 in shown) { print $2 }
  ' <(_render | fzf_visible_keys) "$STATE/data.tsv")

  for k in "${keys[@]}"; do
    grep -qxF "$k" "$STATE/checked" || { all=0; break; }
  done
  for k in "${keys[@]}"; do
    if [ $all -eq 1 ]; then _untick "$k"; else _tick "$k"; fi
  done
  _redraw "$key"
}


# Output of the last run without terminal control codes and script's banner.
_clean_log() {
  sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\a]*\a//g; s/\r$//; s/.*\r//' "$1" \
    | grep -v '^Script \(started\|done\) '
}


# Right-hand panel. Step: label, function and file, its actions, the last
# result and output — or its code before it ran. Action: label and its code.
_preview() {
  local key="$1" func status
  local T=$'\e[1;36m' L=$'\e[90m' G=$'\e[32m' E=$'\e[31m' R=$'\e[0m'
  local rule="$L────────────────────────────────$R"
  case "$key" in
    H:*)
      echo "$T${key#H:}$R"; echo "$rule"
      printf '%s%-11s%s %s\n' "$L" "Steps" "$R" "$(awk -F'\t' -v g="${key#H:}" '$1 == "S" && $3 == g' "$STATE/data.tsv" | grep -c .)"
      return ;;
    U:*) func="${key##*:}" ;;
    S:*) func="${key#S:}" ;;
  esac
  status=$(awk -F'\t' -v f="$func" '$1 == f { print $2 }' "$STATE/status")

  awk -F'\t' -v k="$key" -v status="$status" -v has_log="$([ -s "$STATE/log/$func" ] && echo 1)" '
    BEGIN {
      while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) chk[line] = 1
      T = "\033[1;36m"; L = "\033[90m"; G = "\033[32m"; E = "\033[31m"; R = "\033[0m"
      RULE = L "────────────────────────────────" R
    }
    function field(name, value) { printf "%s%-11s%s %s\n", L, name, R, value }
    { row[NR] = $0 }
    $1 == "S" { step_label[$5] = $4 }
    $2 == k { hit = NR }
    END {
      split(row[hit], f, "\t")
      print T f[4] R
      print RULE
      if (f[1] == "U") field("Part of", step_label[f[7]])
      field("Function", f[5])
      field("File", f[6])
      if (f[1] == "S") {
        if (status == "✓")      field("Last run", G "✓ done" R)
        else if (status == "✗") field("Last run", E "✗ failed" R)
        else if (has_log)       field("Last run", L "skipped" R)
        else                    field("Last run", L "not run yet" R)
      }
      if (f[1] == "S" && f[8] > 0) {
        ticked = ("S:" f[5]) in chk
        print ""
        print T "Actions" R L (ticked ? "  (untick what you do not need)" : "  (tick the step to choose)") R
        print RULE
        for (i = 1; i <= NR; i++) {
          split(row[i], a, "\t")
          if (a[1] != "U" || a[7] != f[5]) continue
          box = ticked ? ((a[2] in chk) ? G "[x]" R " " : "[ ] ") : L "• " R
          print "  " box a[4]
        }
      }
    }
  ' "$STATE/data.tsv"

  echo ""
  if [[ $key == S:* ]] && [ -s "$STATE/log/$func" ]; then
    echo "${T}Output of the last run$R"; echo "$rule"
    _clean_log "$STATE/log/$func"
  else
    echo "${T}Code$R"; echo "$rule"
    cat "$STATE/src/$func" 2>/dev/null
  fi
}


case "$1" in
  --render)  _render; exit ;;
  --header)  _header; exit ;;
  --toggle)  _toggle "$2"; exit ;;
  --group)   _toggle_group "$2"; exit ;;
  --preview) _preview "$2"; exit ;;
esac


# ─── Running one step (inside `script`, so it keeps a real terminal) ─────────

_load_steps() {
  . "$HOME/Dotfiles/scripts/lib/common.sh"
  local f
  for f in "$SYSTEM_DIR"/*.sh "$APPS_DIR"/*.sh; do
    [ -e "$f" ] && . "$f"
  done
}

# --exec <func> [<action func>...] — exit code as menu() reads it: 0 done,
# 1 declined, 2 failed. A failed action inside the step counts as failed even
# when the step itself returns 0.
if [ "$1" = "--exec" ]; then
  shift
  func="$1"; shift
  if [ "$DRY_RUN" = 1 ]; then
    echo ":: [dry run] would run $func${*:+ — actions: $*}"
    exit 0
  fi
  _load_steps
  export STEPS_CONFIRMED=1
  [ $# -gt 0 ] && STEP_ONLY="$*"
  STEP_FAILED=0
  "$func"
  rc=$?
  [ $rc -eq 0 ] && [ "$STEP_FAILED" -eq 1 ] && rc=2
  exit $rc
fi


# ─── Start: load the steps, then loop fzf → confirm → run → fzf ──────────────

export DRY_RUN=1
[ "$1" = "--run" ] && DRY_RUN=0

_load_steps
command -v fzf &>/dev/null || { echo ":: fzf is not installed: $(pkg_install_hint fzf)" >&2; exit 1; }
command -v script &>/dev/null || { echo ":: 'script' (util-linux) is not installed" >&2; exit 1; }

STATE=$(mktemp -d)
export STATE
trap 'rm -rf "$STATE"' EXIT
mkdir -p "$STATE/src" "$STATE/log"
: > "$STATE/checked"
: > "$STATE/status"

# The "Label|func|guard" entries of config_menu, read from install.sh — the
# prototype must not source it, that would start the real installer.
mapfile -t entries < <(
  sed -n '/^config_menu() {/,/^}/p' "$HOME/Dotfiles/install.sh" \
    | grep -oE '^[[:blank:]]+"[^"]*\|[^"]*"' | sed -E 's/^[[:blank:]]+"//; s/"$//'
)

_row() { local IFS=$'\t'; printf '%s\n' "$*"; }

# Group = the directory the function is defined in.
shopt -s extdebug
declare -A group_rows=()
for e in "${entries[@]}"; do
  IFS='|' read -r label func guard <<< "$e"
  [ -n "$guard" ] && ! guard_passes "$guard" && continue
  file=$(declare -F "$func" | cut -d' ' -f3-)
  case "$file" in
    "$SYSTEM_DIR"/*) group="System" ;;
    "$APPS_DIR"/*)   group="Apps" ;;
    *)               group="Other" ;;
  esac
  declare -f "$func" > "$STATE/src/$func"

  # Actions that apply on this machine, from <func>_steps
  subs=""
  if declare -p "${func}_steps" &>/dev/null; then
    declare -n _steps="${func}_steps"
    for s in "${_steps[@]}"; do
      IFS='|' read -r slabel sfunc sguard <<< "$s"
      [ -n "$sguard" ] && ! guard_passes "$sguard" && continue
      declare -f "$sfunc" > "$STATE/src/$sfunc"
      subs+="$(_row U "U:$func:$sfunc" "$group" "$slabel" "$sfunc" "${file#"$HOME/Dotfiles/"}" "$func" 0)"$'\n'
    done
    unset -n _steps
  fi
  group_rows[$group]+="$(_row S "S:$func" "$group" "$label" "$func" "${file#"$HOME/Dotfiles/"}" "" "$(grep -c . <<< "$subs")")"$'\n'"$subs"
done
shopt -u extdebug

for group in System Apps Other; do
  [ -n "${group_rows[$group]}" ] || continue
  _row H "H:$group" "$group" "" "" "" "" 0
  printf '%s' "${group_rows[$group]}"
done | grep . > "$STATE/data.tsv"

fzf_base_opts "Configuration" "$(fzf_keys "j/k ↑↓" move Space tick Ctrl-A "tick whole group" "/ Ctrl-F" search)
$(fzf_keys Enter "run ticked (or current)" Esc back Ctrl-/ "hide preview")
"$'\e[32m'"✓"$'\e[0m'" done   "$'\e[31m'"✗"$'\e[0m'" failed   "$'\e[32m'"[x]"$'\e[0m'" ticked   [+N] actions (unfold when ticked)"

# What will run: "<func>\t<label>\t<action funcs>\t<action labels>" per step, in
# list order. Nothing ticked → the step under the cursor ($1), all its actions.
_plan() {
  awk -F'\t' -v cur="$1" '
    BEGIN { while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) { chk[line] = 1; any = 1 } }
    $1 == "S" { order[++n] = $5; label[$5] = $4; has[$5] = $8 > 0 }
    $1 == "U" && (!any || ($2 in chk)) { af[$7] = af[$7] " " $5; al[$7] = al[$7] ", " $4 }
    END {
      for (i = 1; i <= n; i++) {
        f = order[i]
        if (any ? !(("S:" f) in chk) : f != cur) continue
        if (has[f] && af[f] == "") continue        # every action unticked
        printf "%s\t%s\t%s\t%s\n", f, label[f], substr(af[f], 2), substr(al[f], 3)
      }
    }
  ' "$STATE/data.tsv"
}

while true; do
  picked=$(_render | SHELL=/bin/bash fzf "${FZF_OPTS[@]}" \
    --header="$(_header)" \
    --preview="$CMD --preview {1}" \
    --preview-window='right,50%,wrap' \
    --bind="space:transform:$CMD --toggle {1}" \
    --bind="tab:transform:$CMD --toggle {1}" \
    --bind="ctrl-a:transform:$CMD --group {1}")
  [ $? -eq 0 ] || break

  key=$(cut -f1 <<< "$picked")
  cur="${key#S:}"; cur="${cur#U:}"; cur="${cur%%:*}"
  mapfile -t plan < <(_plan "$cur")
  [ ${#plan[@]} -gt 0 ] || continue

  summary=""
  for p in "${plan[@]}"; do
    IFS=$'\t' read -r func label afuncs alabels <<< "$p"
    summary+="  • $label${alabels:+: $alabels}"$'\n'
  done
  gum confirm "Run ${#plan[@]} step(s)?
$summary" </dev/tty || continue

  results=()
  for p in "${plan[@]}"; do
    IFS=$'\t' read -r func label afuncs alabels <<< "$p"
    echo ""
    gum style --bold --foreground 212 "━━ $label ━━"
    # shellcheck disable=SC2086  # afuncs is a word list on purpose
    SHELL=/bin/bash script -qefc "$CMD --exec $func $afuncs" "$STATE/log/$func"
    rc=$?

    # Same mapping as menu(): 0 done, 1 declined (no mark), anything else failed.
    grep -v "^$func"$'\t' "$STATE/status" > "$STATE/status.tmp"
    case $rc in
      0) printf '%s\t✓\n' "$func" >> "$STATE/status.tmp"; results+=($'\e[32m✓\e[0m '"$label") ;;
      1) results+=($'\e[90m–\e[0m '"$label (skipped)") ;;
      *) printf '%s\t✗\n' "$func" >> "$STATE/status.tmp"; results+=($'\e[31m✗\e[0m '"$label (exit $rc)") ;;
    esac
    mv "$STATE/status.tmp" "$STATE/status"
  done
  : > "$STATE/checked"

  echo ""
  gum style --bold "Summary"
  printf '  %s\n' "${results[@]}"
  echo ""
  read -rp ":: Enter: back to the list (each step's output is in its preview) " _ </dev/tty
done
