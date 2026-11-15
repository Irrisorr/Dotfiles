#!/bin/bash
#
# fonts: one interface font, one monospace font and the interface size, written
# to every place that keeps its own:
#   fontconfig  fontconfig/fonts.conf — what sans-serif, serif, system-ui and
#               monospace mean: Electron apps, niri, alacritty, web pages and
#               everything else that asks for a generic family
#   GTK         gsettings (font-name, document-, monospace-font-name), settings.ini
#   Qt          qt5ct/qt5ct.conf, qt6ct/qt6ct.conf (VLC)
#   DMS         fontFamily, monoFontFamily in dms/settings.json
#   Zen         font.name.* in zen-browser/user.js (on Zen's next start)
#   kitty       font_family (monospace; running kittys reload it)
#   VS Code     editor and terminal font (monospace)
# The choice lives in the dotfiles: the families in fontconfig/fonts.conf, the
# size in qt5ct.conf. fonts_restore (installer) puts back what is outside them.
# Telegram and Obsidian keep their own fonts; set them in their settings.

FT_DOTS="$HOME/Dotfiles"
FT_FONTCONFIG="$FT_DOTS/fontconfig/fonts.conf"
FT_QT=("$FT_DOTS/qt5ct/qt5ct.conf" "$FT_DOTS/qt6ct/qt6ct.conf")
FT_DMS="$FT_DOTS/dms/settings.json"
FT_ZEN="$FT_DOTS/zen-browser/user.js"
FT_KITTY="$FT_DOTS/kitty/kitty.conf"
FT_VSCODE="$HOME/.config/Code/User/settings.json"
FT_GTK_INI=("$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini")
FT_SAMPLE=$'The quick brown fox jumps over the lazy dog\nСъешь же ещё этих мягких французских булок\n0123456789 ->  => != <= {}[]() #include\n   󰈹'

# fzf preview: the family drawn in its own font (kitty), else what fontconfig
# has of it.
if [ "$1" = --sample ]; then
  file=$(fc-match -f '%{file}' "$2")
  if [ -n "$KITTY_WINDOW_ID" ] && command -v magick &>/dev/null; then
    img=$(mktemp --suffix .png)
    magick -background '#1e1e2e' -fill '#cdd6f4' -font "$file" -pointsize 30 \
      label:"$2"$'\n\n'"$FT_SAMPLE" -bordercolor '#1e1e2e' -border 20 "$img" 2>/dev/null &&
      kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
        --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" "$img"
    rm -f "$img"
  else
    echo "$2"
    echo
    fc-list -f '  %{style[0]}\n' "$2" | sort -u
    echo
    echo "File: $file"
  fi
  exit
fi

. "$HOME/Dotfiles/scripts/lib/common.sh"

# ─── Current choice ───────────────────────────────────────────────────────────

# ft_alias <generic> — the family fonts.conf puts first for it.
ft_alias() {
  awk -v g="$1" '
    /<alias/ { a = 1; fam = "" }
    a && match($0, /<family>[^<]*<\/family>/) {
      f = substr($0, RSTART + 8, RLENGTH - 17)
      if (fam == "") fam = f; else if (fam == g) { print f; exit }
    }
    /<\/alias>/ { a = 0 }
  ' "$FT_FONTCONFIG" 2>/dev/null
}

ft_ui()   { local f; f=$(ft_alias sans-serif); echo "${f:-$(fc-match -f '%{family[0]}' sans-serif)}"; }
ft_mono() { local f; f=$(ft_alias monospace);  echo "${f:-$(fc-match -f '%{family[0]}' monospace)}"; }
ft_size() {
  local s
  s=$(sed -n 's/^general="[^,]*,\([0-9.]*\),.*/\1/p' "${FT_QT[0]}" 2>/dev/null)
  echo "${s:-11}"
}

# ─── Writers ──────────────────────────────────────────────────────────────────

ft_xml() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<<"$1"; }

ft_write_fontconfig() {
  local ui mono g
  ui=$(ft_xml "$1") mono=$(ft_xml "$2")
  mkdir -p "$(dirname "$FT_FONTCONFIG")"
  {
    echo '<?xml version="1.0"?>'
    echo '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
    echo '<!-- Written by `fonts` (scripts/functions/fonts.sh) -->'
    echo '<fontconfig>'
    for g in sans-serif serif system-ui; do
      printf '  <alias binding="same">\n    <family>%s</family>\n    <prefer><family>%s</family></prefer>\n  </alias>\n' "$g" "$ui"
    done
    printf '  <alias binding="same">\n    <family>monospace</family>\n    <prefer><family>%s</family></prefer>\n  </alias>\n' "$mono"
    echo '</fontconfig>'
  } >"$FT_FONTCONFIG"
}

ft_write_gtk() {
  local ui=$1 mono=$2 size=$3 f
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface font-name "$ui $size"
    gsettings set org.gnome.desktop.interface document-font-name "$ui $size"
    gsettings set org.gnome.desktop.interface monospace-font-name "$mono $size"
  fi
  for f in "${FT_GTK_INI[@]}"; do
    [ -f "$f" ] && sed -i "s|^gtk-font-name=.*|gtk-font-name=$ui $size|" "$f"
  done
}

# qtct keeps a QFont string: family,size,-1,5,weight,…
ft_write_qt() {
  local ui=$1 mono=$2 size=$3 f
  for f in "${FT_QT[@]}"; do
    [ -f "$f" ] || continue
    sed -i -e "s|^general=.*|general=\"$ui,$size,-1,5,50,0,0,0,0,0\"|" \
      -e "s|^fixed=.*|fixed=\"$mono,$size,-1,5,50,0,0,0,0,0\"|" "$f"
  done
}

# In place (cat >), so the file and its link stay; DMS rereads it.
ft_write_dms() {
  local tmp
  [ -f "$FT_DMS" ] || return 0
  tmp=$(mktemp)
  jq --indent 2 --arg u "$1" --arg m "$2" '.fontFamily = $u | .monoFontFamily = $m' "$FT_DMS" >"$tmp" || { rm -f "$tmp"; return 2; }
  # DMS writes it without a last newline; keep it that way (no diff noise).
  [ -n "$(tail -c1 "$FT_DMS")" ] && truncate -s -1 "$tmp"
  cmp -s "$tmp" "$FT_DMS" || cat "$tmp" >"$FT_DMS"
  rm -f "$tmp"
}

# The Fonts block of user.js gets every font.name line rewritten; the rest of
# the block (sizes) stays.
ft_write_zen() {
  local ui=$1 mono=$2 tmp
  [ -f "$FT_ZEN" ] || return 0
  tmp=$(mktemp)
  awk -v ui="$ui" -v mono="$mono" '
    /^user_pref\("font\.name\./ { next }
    { print }
    /^\/\/ ─── Fonts/ {
      n = split("x-western x-cyrillic", lang, " ")
      for (i = 1; i <= n; i++) {
        printf "user_pref(\"font.name.serif.%s\", \"%s\");\n", lang[i], ui
        printf "user_pref(\"font.name.sans-serif.%s\", \"%s\");\n", lang[i], ui
        printf "user_pref(\"font.name.monospace.%s\", \"%s\");\n", lang[i], mono
      }
    }
  ' "$FT_ZEN" >"$tmp" && cat "$tmp" >"$FT_ZEN"
  rm -f "$tmp"
}

ft_write_kitty() {
  [ -f "$FT_KITTY" ] || return 0
  sed -i "s|^font_family .*|font_family      family='$1'|" "$FT_KITTY"
  pkill -USR1 -x kitty 2>/dev/null
  return 0
}

# settings.json may be JSONC (comments, trailing commas) — jq can't read that.
ft_write_vscode() {
  local tmp
  [ -f "$FT_VSCODE" ] || return 0
  tmp=$(mktemp)
  if jq --indent 2 --arg m "$1" '."editor.fontFamily" = $m | ."terminal.integrated.fontFamily" = $m' "$FT_VSCODE" >"$tmp" 2>/dev/null; then
    cat "$tmp" >"$FT_VSCODE"
  else
    print_error_message "VS Code: can't parse $FT_VSCODE — set the font there yourself"
  fi
  rm -f "$tmp"
}

# fonts_apply <ui> <mono> <size> — everywhere.
fonts_apply() {
  ft_write_fontconfig "$1" "$2"
  ft_write_gtk "$1" "$2" "$3"
  ft_write_qt "$1" "$2" "$3"
  ft_write_dms "$1" "$2"
  ft_write_zen "$1" "$2"
  ft_write_kitty "$2"
  ft_write_vscode "$2"
}

# Installer: link fontconfig/ and write what isn't in the dotfiles (GTK, VS Code).
fonts_restore() {
  create_symlink "$FT_DOTS/fontconfig" "$HOME/.config/fontconfig" || return 2
  [ -f "$FT_FONTCONFIG" ] || return 0
  ft_write_gtk "$(ft_ui)" "$(ft_mono)" "$(ft_size)"
  ft_write_vscode "$(ft_mono)"
}

# ─── Status ───────────────────────────────────────────────────────────────────

ft_mark() { [ "$1" = "$2" ] && printf '\e[32m✓\e[0m' || printf '\e[33m✗\e[0m'; }

# What each place uses now, ✓ when it matches the choice.
ft_status() {
  local ui mono size v
  ui=$(ft_ui) mono=$(ft_mono) size=$(ft_size)
  printf '\e[1m%-11s %-34s %s\e[0m\n' "" "Interface" "Monospace"
  printf '%-11s %s %-32s %s %s\n' fontconfig "$(ft_mark "$(fc-match -f '%{family[0]}' sans-serif)" "$ui")" \
    "$(fc-match -f '%{family[0]}' sans-serif)" "$(ft_mark "$(fc-match -f '%{family[0]}' monospace)" "$mono")" \
    "$(fc-match -f '%{family[0]}' monospace)"
  if command -v gsettings &>/dev/null; then
    v=$(gsettings get org.gnome.desktop.interface font-name | tr -d "'")
    local m
    m=$(gsettings get org.gnome.desktop.interface monospace-font-name | tr -d "'")
    printf '%-11s %s %-32s %s %s\n' GTK "$(ft_mark "$v" "$ui $size")" "$v" "$(ft_mark "$m" "$mono $size")" "$m"
  fi
  v=$(sed -n 's/^general="\([^,]*\),\([^,]*\),.*/\1 \2/p' "${FT_QT[0]}" 2>/dev/null)
  m=$(sed -n 's/^fixed="\([^,]*\),\([^,]*\),.*/\1 \2/p' "${FT_QT[0]}" 2>/dev/null)
  printf '%-11s %s %-32s %s %s\n' Qt "$(ft_mark "$v" "$ui $size")" "$v" "$(ft_mark "$m" "$mono $size")" "$m"
  v=$(jq -r '.fontFamily // ""' "$FT_DMS" 2>/dev/null)
  m=$(jq -r '.monoFontFamily // ""' "$FT_DMS" 2>/dev/null)
  printf '%-11s %s %-32s %s %s\n' DMS "$(ft_mark "$v" "$ui")" "$v" "$(ft_mark "$m" "$mono")" "$m"
  v=$(sed -n 's/^user_pref("font\.name\.sans-serif\.x-western", "\(.*\)");/\1/p' "$FT_ZEN" 2>/dev/null)
  m=$(sed -n 's/^user_pref("font\.name\.monospace\.x-western", "\(.*\)");/\1/p' "$FT_ZEN" 2>/dev/null)
  printf '%-11s %s %-32s %s %s\n' Zen "$(ft_mark "$v" "$ui")" "${v:-(fontconfig)}" "$(ft_mark "$m" "$mono")" "${m:-(fontconfig)}"
  m=$(sed -n "s/^font_family .*family='\([^']*\)'.*/\1/p" "$FT_KITTY" 2>/dev/null)
  printf '%-11s   %-32s %s %s\n' kitty "—" "$(ft_mark "$m" "$mono")" "$m"
  if [ -f "$FT_VSCODE" ]; then
    m=$(jq -r '."editor.fontFamily" // "(default)"' "$FT_VSCODE" 2>/dev/null || echo "(can't read)")
    printf '%-11s   %-32s %s %s\n' "VS Code" "—" "$(ft_mark "$m" "$mono")" "$m"
  fi
}

# ─── Menu ─────────────────────────────────────────────────────────────────────

# ft_pick <label> [mono] — a family from fzf, previewed in itself.
ft_pick() {
  local q=()
  [ "$2" = mono ] && q=(:spacing=mono)
  fc-list "${q[@]}" -f '%{family[0]}\n' | sort -u |
    SHELL=/bin/bash fzf --layout reverse --height 100% --style full \
      --list-label " $1 " --prompt "font> " \
      --header "Enter: use it everywhere · Esc: back" \
      --preview "bash $(printf %q "$(readlink -f "${BASH_SOURCE[0]}")") --sample {}" \
      --preview-window right,60%
}

fonts() {
  require_gum fonts || return 1
  command -v fzf &>/dev/null || { print_error_message "fonts needs fzf"; return 1; }
  local ui mono size act f
  while true; do
    ui=$(ft_ui) mono=$(ft_mono) size=$(ft_size)
    echo
    ft_status
    echo
    act=$(gum choose --header "Fonts" \
      "Interface font — $ui" \
      "Monospace font — $mono" \
      "Interface size — $size" \
      "Write it everywhere again" \
      "🚪 Exit" </dev/tty) || return 0
    case $act in
      Interface*font*) f=$(ft_pick "Interface font") && [ -n "$f" ] && ui=$f || continue ;;
      Monospace*) f=$(ft_pick "Monospace font" mono) && [ -n "$f" ] && mono=$f || continue ;;
      Interface*size*)
        f=$(gum input --header "Interface size, pt (GTK, Qt)" --value "$size" </dev/tty) || continue
        [[ $f =~ ^[0-9]+(\.[0-9]+)?$ ]] || { print_error_message "Not a number: $f"; continue; }
        size=$f ;;
      Write*) ;;
      *) return 0 ;;
    esac
    fonts_apply "$ui" "$mono" "$size"
    print_success_message "$ui / $mono, $size pt — apps pick it up on their next start (kitty, DMS: now)"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
