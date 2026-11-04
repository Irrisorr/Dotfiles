#!/bin/bash
#
# fzf package picker, used by package_category_selection (lib/helpers.sh):
#
#   fzf_picker.sh --pick <state dir> <out file>
#       writes the picked names to <out file>; exits 1 on Esc. The state dir
#       keeps the cache and the ticks, so the installer can bring the list back
#       as it was when its plan is declined.
#   fzf_picker.sh
#       try the UI on its own: prints what it would install, changes nothing.
#
# One screen for every category. j/k or arrows move (wrapping around), Space
# ticks, / or Ctrl-F searches (see lib/fzf.sh). Ticking a package unfolds its
# dependencies (packages.txt "- " lines) right under it, all ticked; unticking
# it folds them away again. Ctrl-A ticks the cursor's whole category (what the
# search shows of it), or unticks it when all are. Enter takes the ticked
# packages, or the one under the cursor when none is.
#
# fzf runs this same script for every key press (--render / --toggle /
# --preview), so those modes read a cache built once at start (in $STATE,
# exported to them) instead of sourcing the installer libs and querying the
# package manager each time.
#
# Ubuntu 26.04 has fzf 0.67: no --id-nth to keep the cursor on the same row
# across a reload, so the row's new position is computed and the cursor moved
# there with pos().

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
CMD="bash $(printf %q "$SELF")"     # works without the exec bit
. "$HOME/Dotfiles/scripts/lib/fzf.sh"

# data.tsv columns: kind  key  category  parent  name  description  mark  deps  source
#   kind: H category header, P package, D dependency
#   key:  H:<category>, P:<name>, D:<parent>:<name> — what --toggle gets
# checked: one key per ticked row


# ─── fzf callbacks (cache only, no installer libs) ────────────────────────────

_render() {
  awk -F'\t' '
    BEGIN {
      while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) chk[line] = 1
      G = "\033[32m"; Y = "\033[33m"; D = "\033[90m"; B = "\033[1;36m"; R = "\033[0m"
    }
    function mark(m) {
      gsub(/↑/, Y "↑" G, m)
      return m == "" ? "" : "  " G m R
    }
    function desc(d) { return d == "" ? "" : " " D "(" d ")" R }
    # Searchable owner: a query for a category or a package keeps its rows
    function tag(t) { return "  " D "· " t R }
    $1 == "H" { printf "%s\t%s%s%s\n", $2, B, $3, R; next }
    $1 == "P" {
      box = ($2 in chk) ? G "[x]" R : "[ ]"
      deps = $8 > 0 ? "  " D "[+" $8 "]" R : ""
      printf "%s\t  %s %s%s%s%s%s\n", $2, box, $5, desc($6), mark($7), deps, tag($3)
      next
    }
    $1 == "D" {
      if (!(("P:" $4) in chk)) next
      box = ($2 in chk) ? G "[x]" R : "[ ]"
      printf "%s\t      %s└ %s%s %s%s%s%s\n", $2, D, R, box, $5, desc($6), mark($7), tag($4)
    }
  ' "$STATE/data.tsv"
}


_header() {
  local p d
  p=$(grep -c '^P:' "$STATE/checked")
  d=$(grep -c '^D:' "$STATE/checked")
  echo "Selected: $p package(s) + $d dependencies"
}


_tick() {   # <P:name | D:parent:name> — a package brings all its dependencies
  grep -qxF "$1" "$STATE/checked" && return
  echo "$1" >> "$STATE/checked"
  [[ $1 == P:* ]] && awk -F'\t' -v p="${1#P:}" '$1 == "D" && $4 == p { print $2 }' \
    "$STATE/data.tsv" >> "$STATE/checked"
}


_untick() {   # a package takes its dependencies with it
  local tmp="$STATE/checked.tmp"
  grep -vxF "$1" "$STATE/checked" > "$tmp"
  [[ $1 == P:* ]] && { grep -v "^D:${1#P:}:" "$tmp" > "$tmp.2"; mv "$tmp.2" "$tmp"; }
  mv "$tmp" "$STATE/checked"
}


# fzf actions to run next: re-render, put the cursor back on <key>, refresh the
# header. change-header goes last in its ":" form, so the text needs no escaping.
_redraw() {
  printf 'reload-sync(%s --render)+pos(%d)+change-header:%s' "$CMD" \
    "$(_render | fzf_visible_keys | fzf_pos_of "$1")" "$(_header)"
}


_toggle() {
  case "$1" in
    H:*) ;;
    *) if grep -qxF "$1" "$STATE/checked"; then _untick "$1"; else _tick "$1"; fi ;;
  esac
  _redraw "$1"
}


# Ctrl-A: the visible packages of the cursor's category, skipping those this
# distro doesn't install. All ticked → untick them, otherwise tick the rest.
_toggle_group() {
  local key="$1" category k all=1
  local -a keys=()
  category=$(awk -F'\t' -v k="$key" '$2 == k { print $3; exit }' "$STATE/data.tsv")

  mapfile -t keys < <(awk -F'\t' -v c="$category" '
    FILENAME != ARGV[2] { shown[$0] = 1; next }
    $1 == "P" && $3 == c && ($2 in shown) && $9 !~ /^nothing/ { print $2 }
  ' <(_render | fzf_visible_keys) "$STATE/data.tsv")

  for k in "${keys[@]}"; do
    grep -qxF "$k" "$STATE/checked" || { all=0; break; }
  done
  for k in "${keys[@]}"; do
    if [ $all -eq 1 ]; then _untick "$k"; else _tick "$k"; fi
  done
  _redraw "$key"
}


# Right-hand panel: name and description up top, then labelled fields; the
# "| ..." notes of a description (Ubuntu: ...) get their own lines.
_preview() {
  awk -F'\t' -v key="$1" '
    BEGIN {
      while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) chk[line] = 1
      T = "\033[1;36m"; I = "\033[3m"; L = "\033[90m"; G = "\033[32m"; Y = "\033[33m"; R = "\033[0m"
      RULE = L "────────────────────────────────" R
    }
    function field(name, value) { printf "%s%-11s%s %s\n", L, name, R, value }
    { row[NR] = $0 }
    $2 == key { hit = NR }
    END {
      if (!hit) exit
      split(row[hit], f, "\t")
      if (f[1] == "H") {
        print T f[3] R
        print RULE
        n = 0
        for (i = 1; i <= NR; i++) { split(row[i], r, "\t"); if (r[1] == "P" && r[3] == f[3]) n++ }
        field("Packages", n)
        exit
      }

      print T f[5] R
      notes = split(f[6], part, "|")
      for (i = 1; i <= notes; i++) { sub(/^ +/, "", part[i]); sub(/ +$/, "", part[i]) }
      # A description that is only a distro note ("Ubuntu: ...") goes to Notes
      first = (notes > 0 && part[1] !~ /^(Ubuntu|Debian|Arch):/) ? 2 : 1
      if (first == 2 && part[1] != "") print I part[1] R
      print RULE
      if (f[1] == "D") field("Needed by", f[4])
      field("Category", f[3])
      field("Installs", f[9])
      if (f[7] == "")      field("Status", L "not installed" R)
      else if (f[7] ~ /↑/) field("Status", Y "✓ installed, ↑ update available" R)
      else                 field("Status", G "✓ installed" R)
      for (i = first; i <= notes; i++) field(i == first ? "Notes" : "", part[i])

      if (f[1] == "P" && f[8] > 0) {
        ticked = ("P:" f[5]) in chk
        print ""
        print T "Dependencies" R L (ticked ? "  (untick what you do not need)" : "  (tick the package to choose)") R
        print RULE
        for (i = 1; i <= NR; i++) {
          split(row[i], d, "\t")
          if (d[1] != "D" || d[4] != f[5]) continue
          box = ticked ? ((d[2] in chk) ? G "[x]" R " " : "[ ] ") : L "• " R
          mark = d[7] == "" ? "" : (d[7] ~ /↑/ ? "  " Y "✓ ↑" R : "  " G "✓" R)
          desc = d[6]; sub(/ *\|.*/, "", desc)
          printf "  %s%s%s%s\n", box, d[5], mark, desc == "" ? "" : "  " L desc R
        }
      }
    }
  ' "$STATE/data.tsv"
}


case "$1" in
  --render)  _render; exit ;;
  --header)  _header; exit ;;
  --toggle)  _toggle "$2"; exit ;;
  --group)   _toggle_group "$2"; exit ;;
  --preview) _preview "$2"; exit ;;
esac


# ─── Start: build the cache with the real installer libs, then run fzf ────────

. "$HOME/Dotfiles/scripts/lib/common.sh"

command -v fzf &>/dev/null || { echo ":: fzf is not installed: $(pkg_install_hint fzf)" >&2; exit 1; }

# Where a package comes from on this machine, for the preview.
declare -A _ARCH_REPO=()
if is_arch; then
  while IFS= read -r p; do _ARCH_REPO[$p]=1; done < <(pacman -Slq 2>/dev/null)
fi

_source_of() {
  local backend value repo bin
  IFS=$'\x1f' read -r backend value repo bin < <(resolve_package "$1")
  case "$backend" in
    native)
      if is_arch; then
        [ -n "${_ARCH_REPO[$value]}" ] && echo "pacman ($value)" || echo "AUR ($value)"
      else
        echo "apt ($value)${repo:+ from ppa:$repo}"
      fi
      ;;
    flatpak) echo "Flathub ($value)" ;;
    snap)    echo "snap ($value)" ;;
    url)     echo "download ($value)" ;;
    source)  echo "own installer (install_source_$value)" ;;
    skip)    echo "nothing — not available on $DISTRO" ;;
    *)       echo "$backend ($value)" ;;
  esac
}

if [ "$1" = "--pick" ]; then
  STATE="$2" OUT="$3"
else
  STATE=$(mktemp -d) OUT=""
  trap 'rm -rf "$STATE"' EXIT
fi
export STATE
[ -e "$STATE/checked" ] || : > "$STATE/checked"

# Built once per installer run; a declined plan comes back to the same list.
if [ ! -s "$STATE/data.tsv" ]; then
  echo ":: Reading packages.txt and checking what is installed..."
  load_package_status

  # One row per header / package / dependency; a package's dependency count is
  # only known after its "- " lines, so a category is read whole first.
  _row() { local IFS=$'\t'; printf '%s\n' "$*"; }

  {
    while IFS= read -r category; do
      _row H "H:$category" "$category" "" "" "" "" "" ""
      mapfile -t lines < <(_category_lines "$category")
      declare -A ndeps=()
      parent=""
      for line in "${lines[@]}"; do
        _split_package_line "$line"
        [[ $line == -* ]] && ndeps[$parent]=$(( ${ndeps[$parent]:-0} + 1 )) || parent="$_PKG_NAME"
      done
      for line in "${lines[@]}"; do
        _split_package_line "$line"
        name="$_PKG_NAME" desc=""
        [[ $line == *"("* ]] && { desc="${line#*(}"; desc="${desc%)*}"; }
        if [[ $line == -* ]]; then
          _row D "D:$parent:$name" "$category" "$parent" "$name" "$desc" "$(package_mark "$name")" 0 "$(_source_of "$name")"
        else
          parent="$name"
          _row P "P:$name" "$category" "" "$name" "$desc" "$(package_mark "$name")" "${ndeps[$name]:-0}" "$(_source_of "$name")"
        fi
      done
      unset ndeps
    done < <(get_all_categories)
  } > "$STATE/data.tsv"
fi

fzf_base_opts "Packages" "$(fzf_keys "j/k ↑↓" move Space tick Ctrl-A "tick whole category" "/ Ctrl-F" search)
$(fzf_keys Enter install Esc cancel Ctrl-/ "hide preview")
"$'\e[32m'"✓"$'\e[0m'" installed   "$'\e[33m'"↑"$'\e[0m'" update available   "$'\e[32m'"[x]"$'\e[0m'" ticked   [+N] dependencies (unfold when ticked)"

# Parents in packages.txt order, each followed by its ticked dependencies;
# a dependency shared by two parents is listed once.
_ticked_names() {
  awk -F'\t' '
    BEGIN { while ((getline line < (ENVIRON["STATE"] "/checked")) > 0) chk[line] = 1 }
    ($1 == "P" || $1 == "D") && ($2 in chk) && !seen[$5]++ { print $5 }
  ' "$STATE/data.tsv"
}

while true; do
  picked=$(_render | SHELL=/bin/bash fzf "${FZF_OPTS[@]}" \
    --header="$(_header)" \
    --preview="$CMD --preview {1}" \
    --preview-window='right,45%,wrap' \
    --bind="space:transform:$CMD --toggle {1}" \
    --bind="tab:transform:$CMD --toggle {1}" \
    --bind="ctrl-a:transform:$CMD --group {1}")
  [ $? -eq 0 ] || exit 1

  # Nothing ticked → the package under the cursor, with its dependencies.
  if ! grep -q . "$STATE/checked"; then
    key=$(cut -f1 <<< "$picked")
    [[ $key == [PD]:* ]] || continue
    [[ $key == D:* ]] && key="P:$(cut -d: -f2 <<< "$key")"
    _tick "$key"
  fi
  mapfile -t names < <(_ticked_names)

  # The installer shows its own plan and asks; on its own, ask here.
  if [ -n "$OUT" ]; then
    printf '%s\n' "${names[@]}" > "$OUT"
    exit 0
  fi
  gum confirm "Install ${#names[@]} package(s)?
$(printf '  • %s\n' "${names[@]}")" </dev/tty && break
done

echo ":: Would install ${#names[@]} package(s) (trying the picker on its own — nothing installed):"
printf '   %s\n' "${names[@]}"
