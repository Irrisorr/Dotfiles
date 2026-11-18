#!/bin/bash
#
# defapps: which app opens what. Two parts:
#   Default apps  roles like DMS has them (browser, terminal, file manager, ...):
#                 one pick writes the role's whole group of types; terminal,
#                 browser and file manager also rewrite their niri bind line.
#   File types    an fzf tree of every type by category; tick rows and pick the
#                 app. "Your extensions" adds extensions the system doesn't know.
# Apps that hide from Open with (swayimg) or don't claim a type (VS Code for
# text) are offered too. Choices land in ~/.config/mimeapps.list (terminal:
# ~/.config/xdg-terminals.list) — the files DMS's Default apps, xdg-open, the
# portals and dfiles read.
#
# Like the installer's fzf menus, fzf calls this script back on every key
# press; those modes only read the cache in $DA_STATE:
#   apps.tsv      id  name  hidden  mimes  exec  path  categories  wmclass
#   types.tsv     category  mime  extensions  custom(1 = from Your extensions)
#   defaults.tsv  mime  id  kind  via  missing  source    (what opens it now)
#   checked       ticked mime types;  open: unfolded categories

DA_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DA_CMD="bash $(printf %q "$DA_SELF")"
DA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DA_MIMEAPPS="$DA_CONFIG/mimeapps.list"
DA_TERMINALS="$DA_CONFIG/xdg-terminals.list"
DA_BINDS="$DA_CONFIG/niri/conf/binds.kdl"
# sensitive_rules.kdl: this PC's own rules, not in git, may be missing
DA_RULES=("$DA_CONFIG/niri/conf/rules.kdl" "$DA_CONFIG/niri/conf/sensitive_rules.kdl")
DA_MIME_DIR=/usr/share/mime
DA_USER_MIME="${XDG_DATA_HOME:-$HOME/.local/share}/mime"
DA_USER_PKG="$DA_USER_MIME/packages/defapps.xml"
DA_DOTS="${DA_DOTS:-$HOME/Dotfiles/defapps}"
DA_CUSTOM="Your extensions"
. "$HOME/Dotfiles/scripts/lib/fzf.sh"

# "Name|mime ...". Aliases are resolved and types this system doesn't know are
# skipped. "All types" (everything with an extension, every link scheme) comes
# after these.
DA_CATEGORIES=(
  "Images|image/png image/jpeg image/gif image/webp image/avif image/svg+xml image/bmp image/tiff image/heic image/heif image/jxl image/vnd.microsoft.icon image/x-tga image/x-portable-anymap"
  "Text & code|text/plain text/markdown application/json application/x-zerosize text/x-python text/x-python3 application/x-shellscript text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr text/x-java text/javascript application/x-typescript text/css application/yaml application/toml application/xml text/x-go text/rust text/x-lua text/x-makefile text/x-log application/x-desktop text/x-patch"
  "Video|video/mp4 video/x-matroska video/webm video/vnd.avi video/mpeg video/quicktime video/ogg video/x-flv video/3gpp video/mp2t"
  "Audio|audio/mpeg audio/flac audio/vnd.wave audio/ogg audio/x-opus+ogg audio/x-vorbis+ogg audio/aac audio/mp4 audio/x-m4a audio/webm"
  "PDF & books|application/pdf application/epub+zip application/x-mobipocket-ebook application/vnd.comicbook+zip application/vnd.comicbook-rar image/vnd.djvu"
  "Office|application/vnd.openxmlformats-officedocument.wordprocessingml.document application/msword application/vnd.oasis.opendocument.text application/rtf application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/vnd.ms-excel application/vnd.oasis.opendocument.spreadsheet text/csv application/vnd.openxmlformats-officedocument.presentationml.presentation application/vnd.ms-powerpoint application/vnd.oasis.opendocument.presentation"
  "Archives|application/zip application/x-tar application/x-compressed-tar application/x-xz-compressed-tar application/x-zstd-compressed-tar application/x-bzip2-compressed-tar application/x-7z-compressed application/vnd.rar application/gzip application/x-xz application/zstd application/x-bzip2 application/x-iso9660-image"
  "Web & links|x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml x-scheme-handler/mailto x-scheme-handler/tg x-scheme-handler/discord x-scheme-handler/magnet x-scheme-handler/ssh"
  "Folders|inode/directory"
  "Calendar|text/calendar x-scheme-handler/webcal"
)

# "role|Label|niri bind key|mime ...": the same groups DMS's Default apps
# writes, so both show the same. Terminal has no type, it is a list file.
DA_ROLES=(
  "terminal|Terminal|Mod+Return|"
  "browser|Browser|Mod+B|x-scheme-handler/https x-scheme-handler/http text/html application/xhtml+xml"
  "filemanager|File manager|Mod+E|inode/directory x-scheme-handler/file x-scheme-handler/sftp"
  "editor|Text editor||text/plain text/markdown application/x-zerosize text/x-c++src text/x-csrc text/x-python text/x-shellscript application/json"
  "images|Image viewer||image/png image/jpeg image/gif image/bmp image/webp image/avif image/svg+xml image/tiff image/heic image/heif image/jxl"
  "video|Video player||video/mp4 video/x-matroska video/webm video/avi video/mpeg video/quicktime video/x-msvideo"
  "music|Music player||audio/mpeg audio/x-flac audio/wav audio/ogg audio/aac audio/webm"
  "pdf|PDF reader||application/pdf application/x-ext-pdf application/x-bzpdf application/x-gzpdf application/vnd.comicbook-rar application/vnd.comicbook+zip"
  "mail|Mail||x-scheme-handler/mailto"
  "calendar|Calendar||text/calendar x-scheme-handler/calendar x-scheme-handler/webcal x-scheme-handler/webcals"
)

# System and user mime databases together (user: own extensions).
da_mime_cat() {
  cat "$DA_MIME_DIR/$1" "$DA_USER_MIME/$1" 2>/dev/null
}


# ─── fzf callbacks (cache only) ───────────────────────────────────────────────

# While searching every category is unfolded, and "All types" leaves out what
# the categories above already list. "Your extensions" is always first, with
# its "+ Add extension" row.
da_render() {
  awk -F'\t' -v q="$FZF_QUERY" -v custom="$DA_CUSTOM" '
    BEGIN {
      S = ENVIRON["DA_STATE"]
      while ((getline l < (S "/checked")) > 0) chk[l] = 1
      while ((getline l < (S "/open")) > 0) open[l] = 1
      while ((getline l < (S "/apps.tsv")) > 0) { split(l, a, "\t"); name[a[1]] = a[2] }
      while ((getline l < (S "/defaults.tsv")) > 0) {
        split(l, a, "\t"); id[a[1]] = a[2]; kind[a[1]] = a[3]; via[a[1]] = a[4]; miss[a[1]] = a[5]
      }
      G = "\033[32m"; E = "\033[31m"; D = "\033[90m"; B = "\033[1;36m"; R = "\033[0m"
    }
    function app(i) { return (i in name) ? name[i] : i }
    function cut(s, w) { return length(s) > w ? substr(s, 1, w - 1) "…" : s }
    function row(cat, m, e, c,    box, label, who, key) {
      box = (m in chk) ? G "[x]" R : "[ ]"
      label = e != "" ? e : (m ~ /^x-scheme-handler\// ? substr(m, 18) ":" : (m == "inode/directory" ? "folders" : "—"))
      if (c) label = "." e
      if (id[m] == "") who = D "nothing" R
      else if (kind[m] == "user") who = app(id[m])
      else who = D "(system: " app(id[m]) ")" R
      if (via[m] != "") who = who D "  via " via[m] R
      if (miss[m] != "") who = E "✗ " miss[m] " missing" R " → " who
      key = c ? "X:" e "|" m : "M:" cat ":" m
      return sprintf("%s\t    %s %-16s %s%-38s%s → %s", key, box, cut(label, 16), D, cut(m, 38), R, who)
    }
    function flush(    i, best, bi, j, sum, used, unf) {
      if (!started) return
      sum = ""
      delete used
      for (j = 1; j <= 3; j++) {
        best = 0
        for (i in cnt) if (!(i in used) && cnt[i] > best) { best = cnt[i]; bi = i }
        if (best == 0) break
        used[bi] = 1
        sum = sum (sum == "" ? "" : ", ") app(bi) " " best
      }
      unf = (cur in open) || q != ""
      printf "H:%s\t%s%s %s%s  %s%d types%s%s\n", cur, B, (unf ? "▾" : "▸"), cur, R, D, nrows, (sum != "" ? " · " sum : ""), R
      if (unf) {
        for (i = 1; i <= nrows; i++) print rows[i]
        if (cur == custom) printf "A:add\t    %s+ Add extension…%s\n", G, R
      }
      delete rows; delete cnt; nrows = 0
    }
    function begin(c) { flush(); cur = c; started = 1 }
    NR == 1 && $1 != custom { begin(custom) }
    $1 != cur { begin($1) }
    {
      if (q != "" && $1 == "All types" && ($2 in curated)) next
      if ($1 != "All types" && $1 != custom) curated[$2] = 1
      rows[++nrows] = row($1, $2, $3, $4 == 1)
      if (id[$2] != "") cnt[id[$2]]++
    }
    END { if (NR == 0) begin(custom); flush() }
  ' "$DA_STATE/types.tsv"
}


da_header() {
  echo "Ticked: $(grep -c . "$DA_STATE/checked") type(s) · writes $DA_MIMEAPPS"
}


da_redraw() {
  printf 'reload-sync(%s --render)+pos(%d)+change-header:%s' "$DA_CMD" \
    "$(da_render | fzf_visible_keys | fzf_pos_of "$1")" "$(da_header)"
}


# Mime types of a row: one for a type row, the whole category for a header.
da_row_mimes() {
  case "$1" in
    H:*) awk -F'\t' -v c="${1#H:}" '$1 == c { print $2 }' "$DA_STATE/types.tsv" | sort -u ;;
    M:*) echo "${1##*:}" ;;
    X:*) echo "${1#*|}" ;;
  esac
}

# The category a row belongs to.
da_row_cat() {
  case "$1" in
    H:*) echo "${1#H:}" ;;
    M:*) local r=${1#M:}; echo "${r%:*}" ;;
    X:* | A:*) echo "$DA_CUSTOM" ;;
  esac
}


# A header ticks its whole category, or unticks it when all of it is ticked.
da_toggle() {
  local m all=1 tmp="$DA_STATE/checked.tmp"
  local -a mimes
  mapfile -t mimes < <(da_row_mimes "$1")
  [ ${#mimes[@]} -gt 0 ] || { da_redraw "$1"; return; }
  for m in "${mimes[@]}"; do
    grep -qxF "$m" "$DA_STATE/checked" || { all=0; break; }
  done
  if [ $all -eq 1 ]; then
    grep -vxF -f <(printf '%s\n' "${mimes[@]}") "$DA_STATE/checked" >"$tmp"
    mv "$tmp" "$DA_STATE/checked"
  else
    printf '%s\n' "${mimes[@]}" >>"$DA_STATE/checked"
    sort -u -o "$DA_STATE/checked" "$DA_STATE/checked"
  fi
  da_redraw "$1"
}


da_fold() {
  local tmp="$DA_STATE/open.tmp"
  if grep -qxF "${1#H:}" "$DA_STATE/open"; then
    grep -vxF "${1#H:}" "$DA_STATE/open" >"$tmp"
    mv "$tmp" "$DA_STATE/open"
  else
    echo "${1#H:}" >>"$DA_STATE/open"
  fi
  da_redraw "$1"
}


# Enter: back from the search, fold a header, or accept (pick the app for
# the row / add an extension).
da_enter() {
  if [ "$FZF_INPUT_STATE" = enabled ]; then
    echo "hide-input+rebind(j,k,/,space)"
  elif [[ $1 == H:* ]]; then
    da_fold "$1"
  else
    echo accept
  fi
}


da_tab() {
  if [[ $1 == H:* ]]; then da_fold "$1"; else da_toggle "$1"; fi
}


# The type of a row: its description, extensions, what opens it, from where,
# and the apps that declare it.
da_type_preview() {
  local m=$1 note=$2 comment
  comment=$(sed -n 's|^ *<comment>\(.*\)</comment>.*|\1|p' "$DA_MIME_DIR/$m.xml" "$DA_USER_MIME/$m.xml" 2>/dev/null | head -1 |
    sed 's/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&amp;/\&/g')
  awk -F'\t' -v m="$m" -v comment="$comment" -v note="$note" '
    BEGIN {
      S = ENVIRON["DA_STATE"]
      T = "\033[1;36m"; L = "\033[90m"; G = "\033[32m"; E = "\033[31m"; R = "\033[0m"
      while ((getline l < (S "/types.tsv")) > 0) { split(l, a, "\t"); if (a[2] == m && a[4] != 1) ext = a[3] }
      while ((getline l < (S "/defaults.tsv")) > 0) { split(l, a, "\t"); if (a[1] == m) split(l, d, "\t") }
    }
    function field(k, v) { printf "%s%-11s%s %s\n", L, k, R, v }
    { name[$1] = $2; app[++n] = $0 }
    END {
      print T m R (comment != "" ? "  " comment : "")
      print L "────────────────────────────────" R
      if (note != "") { print note; print "" }
      field("Extensions", ext != "" ? ext : "—")
      who = d[2] == "" ? L "nothing" R : ((d[2] in name) ? name[d[2]] : d[2]) L " (" d[2] ")" R
      field("Opens with", who)
      if (d[2] != "") field("Set in", d[6] (d[3] == "user" ? "" : L "  (not chosen by you)" R))
      if (d[4] != "") field("Via", "parent type " d[4] L " — nothing set for this one" R)
      if (d[5] != "") field("Missing", E d[5] R L " is set but not installed" R)
      print ""
      print T "Apps that declare it" R L "  (Enter offers every app)" R
      print L "────────────────────────────────" R
      for (i = 1; i <= n; i++) {
        split(app[i], a, "\t")
        if (index(";" a[4] ";", ";" m ";") == 0) continue
        found = 1
        print "  " (a[1] == d[2] ? G "● " R : "  ") a[2] L "  " a[1] (a[3] == 1 ? "  hidden" : "") R
      }
      if (!found) print L "  none" R
    }
  ' "$DA_STATE/apps.tsv"
}


da_preview() {
  local key=$1 r
  local T=$'\e[1;36m' L=$'\e[90m' R=$'\e[0m'
  case $key in
    H:*)
      echo "$T${key#H:}$R"
      echo "$L────────────────────────────────$R"
      echo "Enter / Tab: fold · Space: tick all · Alt+Enter: one app for all of it"
      echo
      awk -F'\t' -v c="${key#H:}" '
        BEGIN {
          S = ENVIRON["DA_STATE"]
          while ((getline l < (S "/apps.tsv")) > 0) { split(l, a, "\t"); name[a[1]] = a[2] }
          while ((getline l < (S "/defaults.tsv")) > 0) { split(l, a, "\t"); id[a[1]] = a[2] }
        }
        $1 == c { n = id[$2] == "" ? "(nothing)" : ((id[$2] in name) ? name[id[$2]] : id[$2]); cnt[n]++ }
        END { for (n in cnt) printf "  %3d  %s\n", cnt[n], n }
      ' "$DA_STATE/types.tsv" | sort -rn
      ;;
    A:*)
      echo "${T}Add an extension$R"
      echo "$L────────────────────────────────$R"
      echo "The system knows a file's type by its extension (shared-mime-info,"
      echo "/usr/share/mime); apps are set per type, not per extension."
      echo
      echo "An extension it doesn't know can get:"
      echo "  • its own type (application/x-<ext>) with any app, or"
      echo "  • an existing type — e.g. .conf as text/plain opens like text."
      echo "An extension it already knows can also be split off into its own type."
      echo
      echo "Saved in $DA_USER_PKG"
      echo "(update-mime-database runs after; xdg-open, GLib and DMS read it)."
      echo "Ctrl-D on one of your extensions removes it."
      ;;
    X:*)
      r=${key#X:}
      da_type_preview "${r#*|}" "Your extension .${r%%|*} → ${r#*|}  $L(Ctrl-D: remove)$R"
      ;;
    M:*) da_type_preview "${key##*:}" ;;
  esac
}


da_app_preview() {
  awk -F'\t' -v id="$1" '
    $1 == id {
      T = "\033[1;36m"; L = "\033[90m"; R = "\033[0m"
      print T $2 R
      print L "────────────────────────────────" R
      printf "%s%-9s%s %s\n", L, "File", R, $6
      printf "%s%-9s%s %s\n", L, "Runs", R, $5
      if ($7 != "") printf "%s%-9s%s %s\n", L, "Category", R, $7
      if ($3 == 1) printf "%s%-9s%s %s\n", L, "Hidden", R, "NoDisplay — DMS and dfiles leave it out of Open with"
      print ""
      print T "Declares" R
      print L "────────────────────────────────" R
      n = split($4, m, ";")
      for (i = 1; i <= n; i++) if (m[i] != "") print "  " m[i]
      if ($4 == "") print L "  no types — it can still be the default" R
    }
  ' "$DA_STATE/apps.tsv"
}


if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "$1" in
    --render) da_render; exit ;;
    --toggle) da_toggle "$2"; exit ;;
    --tab) da_tab "$2"; exit ;;
    --enter) da_enter "$2"; exit ;;
    --preview) da_preview "$2"; exit ;;
    --app) da_app_preview "$2"; exit ;;
  esac
fi


# ─── Building the cache ───────────────────────────────────────────────────────

. "$HOME/Dotfiles/scripts/lib/common.sh"

# XDG data dirs, user first. Flatpak's exports join XDG_DATA_DIRS only at the
# next login, so apps the installer just put in as flatpaks (Ubuntu) are looked
# up there too; a dir listed twice changes nothing (the first copy of an id wins).
da_data_dirs() {
  local IFS=: d
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
  for d in "$HOME/.local/share/flatpak/exports/share" /var/lib/flatpak/exports/share; do
    [ -d "$d" ] && echo "$d"
  done
}

da_desktops() {
  local desk IFS=:
  for desk in $XDG_CURRENT_DESKTOP; do echo "${desk,,}"; done
}

# mimeapps.list files in lookup order: per dir, the desktop-specific ones
# (niri-mimeapps.list) before the plain one (freedesktop mime-apps spec).
da_mimeapps_files() {
  local dir desk IFS=:
  for dir in "$DA_CONFIG" ${XDG_CONFIG_DIRS:-/etc/xdg}; do
    while read -r desk; do echo "$dir/$desk-mimeapps.list"; done < <(da_desktops)
    echo "$dir/mimeapps.list"
  done
  while IFS= read -r dir; do
    while read -r desk; do echo "$dir/applications/$desk-mimeapps.list"; done < <(da_desktops)
    echo "$dir/applications/mimeapps.list"
  done < <(da_data_dirs)
}

# Desktop entries; the first dir with an id wins, Hidden=true deletes it.
da_build_apps() {
  local dir
  while IFS= read -r dir; do
    [ -d "$dir/applications" ] || continue
    find -L "$dir/applications" -name '*.desktop' -printf '%P\t%p\n' 2>/dev/null
  done < <(da_data_dirs) |
    awk -F'\t' '{ gsub("/", "-", $1) } !seen[$1]++ { print $1 "\t" $2 }' |
    awk -F'\t' '{
      p = $2; name = ""; nd = 0; hid = 0; mt = ""; ex = ""; type = ""; cats = ""; wm = ""; insec = 0
      while ((getline l < p) > 0) {
        if (l ~ /^\[/) { insec = (l == "[Desktop Entry]"); continue }
        if (!insec) continue
        if (l ~ /^Name=/ && name == "") name = substr(l, 6)
        else if (l ~ /^NoDisplay=true/) nd = 1
        else if (l ~ /^Hidden=true/) hid = 1
        else if (l ~ /^MimeType=/) mt = substr(l, 10)
        else if (l ~ /^Exec=/ && ex == "") ex = substr(l, 6)
        else if (l ~ /^Type=/) type = substr(l, 6)
        else if (l ~ /^Categories=/) cats = substr(l, 12)
        else if (l ~ /^StartupWMClass=/) wm = substr(l, 16)
      }
      close(p)
      if (hid || type != "Application") next
      if ($1 == "dms-open.desktop") name = "Ask every time (DMS chooser)"
      print $1 "\t" name "\t" nd "\t" mt "\t" ex "\t" p "\t" cats "\t" wm
    }' |
    # Two apps called "Files" (dfiles, Nautilus): add the id to tell them apart.
    awk -F'\t' -v OFS='\t' '{ row[NR] = $0; n[$2]++ }
      END { for (i = 1; i <= NR; i++) { $0 = row[i]; if (n[$2] > 1) $2 = $2 " (" substr($1, 1, length($1) - 8) ")"; print } }' \
      >"$DA_STATE/apps.tsv"
}

# Your extensions: one <mime-type> line per extension in defapps.xml.
da_custom_list() {
  sed -n 's|.*<mime-type type="\([^"]*\)">.*<glob pattern="\*\.\([^"]*\)".*|\2\t\1|p' "$DA_USER_PKG" 2>/dev/null
}

da_build_types() {
  awk -F'\t' -v cats="$(printf '%s\n' "${DA_CATEGORIES[@]}")" -v custom="$DA_CUSTOM" '
    FILENAME == ARGV[1] {
      if ($0 ~ /^#/) next
      split($0, f, ":")
      if (f[3] ~ /^\*\.[^*?\[]+$/) {
        e = tolower(substr(f[3], 3))
        if (!((f[2] SUBSEP e) in had)) { had[f[2], e]; ext[f[2]] = ext[f[2]] (ext[f[2]] == "" ? "" : " ") e }
      }
      next
    }
    FILENAME == ARGV[2] { split($0, a, " "); al[a[1]] = a[2]; next }
    FILENAME == ARGV[3] { known[$0] = 1; next }
    FILENAME == ARGV[4] { n = split($4, m, ";"); for (i = 1; i <= n; i++) if (m[i] ~ /^x-scheme-handler\//) scheme[m[i]] = 1; next }
    FILENAME == ARGV[5] { k = substr($0, 1, index($0, "=") - 1); if (k ~ /^x-scheme-handler\//) scheme[k] = 1; next }
    FILENAME == ARGV[6] { print custom "\t" $2 "\t" $1 "\t1"; next }
    END {
      nc = split(cats, C, "\n")
      for (c = 1; c <= nc; c++) {
        split(C[c], p, "|")
        nm = split(p[2], M, " ")
        delete dup
        for (i = 1; i <= nm; i++) {
          t = (M[i] in al) ? al[M[i]] : M[i]
          if (t in dup || !(t in known || t ~ /^x-scheme-handler\// || t ~ /^inode\//)) continue
          dup[t] = 1
          print p[1] "\t" t "\t" ext[t] "\t0"
        }
      }
      fflush()
      for (t in known) if (ext[t] != "") print "All types\t" t "\t" ext[t] "\t0" | "sort -t\"\t\" -k2"
      for (t in scheme) print "All types\t" t "\t\t0" | "sort -t\"\t\" -k2"
      close("sort -t\"\t\" -k2")
    }
  ' <(da_mime_cat globs2) <(da_mime_cat aliases) <(da_mime_cat types) "$DA_STATE/apps.tsv" \
    <(cat "$DA_MIMEAPPS" 2>/dev/null) <(da_custom_list) >"$DA_STATE/types.tsv"
}

# Canonical names of mime types (aliases resolved), one per line.
da_canon() {
  awk -v list="$*" '
    FILENAME == ARGV[1] { split($0, a, " "); al[a[1]] = a[2]; next }
    END { n = split(list, m, " "); for (i = 1; i <= n; i++) print (m[i] in al) ? al[m[i]] : m[i] }
  ' <(da_mime_cat aliases) /dev/null
}

# What opens each type now, the way GLib looks it up: [Default Applications]
# of the mimeapps.list files in order (first installed id wins), then
# [Added Associations], then mimeinfo.cache — for the type, then its parents.
da_build_defaults() {
  local files caches dir r
  files=$(da_mimeapps_files)
  caches=$(while IFS= read -r dir; do echo "$dir/applications/mimeinfo.cache"; done < <(da_data_dirs))
  { cut -f2 "$DA_STATE/types.tsv"; for r in "${DA_ROLES[@]}"; do da_canon "${r##*|}"; done; } | sort -u >"$DA_STATE/mimes.txt"
  awk -F'\t' -v files="$files" -v caches="$caches" -v home="$DA_CONFIG/" -v appsf="$DA_STATE/apps.tsv" '
    function canon(t) { return (t in al) ? al[t] : t }
    function read(f, cache,    l, sec, k, v, n, ids, i) {
      sec = cache ? "[MIME Cache]" : ""
      while ((getline l < f) > 0) {
        if (l ~ /^\[/) { sec = l; continue }
        if (!index(l, "=")) continue
        k = canon(substr(l, 1, index(l, "=") - 1)); v = substr(l, index(l, "=") + 1)
        n = split(v, ids, ";")
        for (i = 1; i <= n; i++) {
          if (ids[i] == "") continue
          if (sec == "[Default Applications]") {
            if (ids[i] in inst) { if (!(k in dflt)) { dflt[k] = ids[i]; dsrc[k] = f } }
            else if (!(k in dflt) && !(k in miss) && index(f, home) == 1) miss[k] = ids[i]
          } else if (sec == "[Added Associations]" && (ids[i] in inst) && !(k in added)) {
            added[k] = ids[i]; asrc[k] = f
          } else if (sec == "[MIME Cache]" && (ids[i] in inst) && !(k in cache_)) {
            cache_[k] = ids[i]; csrc[k] = f
          }
        }
      }
      close(f)
    }
    # The type, then its parents, breadth first.
    function chain(t,    h, n, i, p, np) {
      delete C; delete inq
      n = 1; C[1] = t; inq[t] = 1
      for (h = 1; h <= n; h++) {
        np = split(par[C[h]], p, " ")
        for (i = 1; i <= np; i++) if (!(p[i] in inq)) { C[++n] = p[i]; inq[p[i]] = 1 }
      }
      return n
    }
    FILENAME == ARGV[1] { split($0, a, " "); al[a[1]] = a[2]; next }
    FILENAME == ARGV[2] { split($0, a, " "); par[a[1]] = par[a[1]] " " a[2]; next }
    FNR == 1 && !loaded {
      loaded = 1
      while ((getline l < appsf) > 0) { split(l, a, "\t"); inst[a[1]] = 1 }
      n = split(files, F, "\n"); for (i = 1; i <= n; i++) read(F[i], 0)
      n = split(caches, F, "\n"); for (i = 1; i <= n; i++) read(F[i], 1)
    }
    {
      t = $1; n = chain(t); id = ""; via = ""; src = ""; kind = "system"
      for (i = 1; i <= n && id == ""; i++) if (C[i] in dflt) {
        id = dflt[C[i]]; src = dsrc[C[i]]; via = C[i]
        if (index(src, home) == 1) kind = "user"
      }
      for (i = 1; i <= n && id == ""; i++) if (C[i] in added) { id = added[C[i]]; src = asrc[C[i]]; via = C[i] }
      for (i = 1; i <= n && id == ""; i++) if (C[i] in cache_) { id = cache_[C[i]]; src = csrc[C[i]]; via = C[i] }
      if (via == t) via = ""
      print t "\t" id "\t" kind "\t" via "\t" miss[t] "\t" src
    }
  ' <(da_mime_cat aliases) <(da_mime_cat subclasses) "$DA_STATE/mimes.txt" >"$DA_STATE/defaults.tsv"
}

da_build() {
  da_build_apps
  da_build_types
  da_build_defaults
}


# ─── Writing ──────────────────────────────────────────────────────────────────

# da_write <desktop id | ""> <mime>... — set the default for these types, or
# with "" drop it (back to what the system picks). Aliases of the types go too,
# so no old entry under another name shadows the new one.
da_write() {
  local id=$1 file tmp
  shift
  file=$(readlink -f "$DA_MIMEAPPS" 2>/dev/null || echo "$DA_MIMEAPPS")
  [ -f "$file" ] || : >"$file"
  tmp=$(mktemp)
  awk -v id="$id" -v list="$(da_canon "$@" | tr '\n' ' ')" '
    function add(   i) {
      if (id == "" || added) return
      for (i = 1; i <= n; i++) print m[i] "=" id
      added = 1
    }
    # Blank lines wait, so new entries go before the gap above the next section.
    function blanks() { for (; held > 0; held--) print "" }
    function init(   i, k) {
      ready = 1
      n = split(list, m, " ")
      for (i = 1; i <= n; i++) drop[m[i]] = 1
      for (k in al) if (al[k] in drop) drop[k] = 1
    }
    FILENAME == ARGV[1] { split($0, a, " "); al[a[1]] = a[2]; next }
    !ready { init() }
    /^\[/ {
      if (insec) add()
      blanks()
      insec = ($0 == "[Default Applications]")
      seen = seen || insec
      print
      next
    }
    /^$/ { held++; next }
    insec && index($0, "=") && (substr($0, 1, index($0, "=") - 1) in drop) { next }
    { blanks(); print }
    END {
      if (!ready) init()
      if (insec) add()
      else if (!seen && id != "") { blanks(); print "[Default Applications]"; add() }
      blanks()
    }
  ' <(da_mime_cat aliases) "$file" >"$tmp" && cat "$tmp" >"$file"
  rm -f "$tmp"
}

# The terminal goes first in xdg-terminals.list; the others stay as fallbacks.
da_write_terminal() {
  local file
  file=$(readlink -f "$DA_TERMINALS" 2>/dev/null || echo "$DA_TERMINALS")
  { echo "$1"; grep -vxF "$1" "$file" 2>/dev/null; } >"$file.tmp" && cat "$file.tmp" >"$file"
  rm -f "$file.tmp"
}

# First installed terminal of the xdg-terminals.list files (user, then system).
da_current_terminal() {
  local dir desk f id
  local -a dirs files=()
  IFS=: read -ra dirs <<<"$DA_CONFIG:${XDG_CONFIG_DIRS:-/etc/xdg}"
  for dir in "${dirs[@]}"; do
    while read -r desk; do files+=("$dir/$desk-xdg-terminals.list"); done < <(da_desktops)
    files+=("$dir/xdg-terminals.list")
  done
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    while read -r id; do
      [[ -z $id || $id == \#* ]] && continue
      grep -q "^${id}"$'\t' "$DA_STATE/apps.tsv" && { echo "$id"; return; }
    done <"$f"
  done
}


# da_pick_app [--terminal] <mime>... — fzf over every installed app; the ones
# that declare the types (or are terminals) come first. Prints the desktop id.
da_pick_app() {
  local term=0
  [ "$1" = --terminal ] && { term=1; shift; }
  local n=$#
  [ $term = 1 ] && n=1
  awk -F'\t' -v list="$*" -v n="$n" -v term="$term" '
    BEGIN { split(list, m, " ") }
    # The DMS chooser asks which app opens a file; it is no terminal.
    term && $1 == "dms-open.desktop" { next }
    {
      s = 0
      if (term) s = index(";" $7 ";", ";TerminalEmulator;") > 0
      else for (i = 1; i <= n; i++) if (index(";" $4 ";", ";" m[i] ";")) s++
      what = term ? "terminal" : "declares"
      tag = s == n ? "\033[32m✓ " what "\033[0m" : (s > 0 ? "\033[33mdeclares " s "/" n "\033[0m" : "")
      printf "%d\t%s\t%s\t%s  \033[90m%s\033[0m  %s%s\n", s, tolower($2), $1, $2, $1, tag, ($3 ? "  \033[90mhidden\033[0m" : "")
    }
  ' "$DA_STATE/apps.tsv" | sort -t$'\t' -k1,1nr -k2,2 | cut -f3- |
    SHELL=/bin/bash fzf --ansi --delimiter '\t' --with-nth 2 --layout reverse --height 100% \
      --style full --list-label " Pick the app " --prompt "app> " \
      --header "Enter: set as default · Esc: back · ✓ = made for this" \
      --preview "$DA_CMD --app {1}" --preview-window right,45%,wrap |
    cut -f1
}


# ─── niri binds ───────────────────────────────────────────────────────────────

# The bind's action, what is inside { } on its line.
da_bind_action() {
  awk -v key="$1" '
    !/^[ \t]*\/\// && match($0, /^[ \t]*[^ \t]+/) {
      k = substr($0, RSTART, RLENGTH); gsub(/[ \t]/, "", k)
      if (k == key && index($0, "{")) {
        a = substr($0, index($0, "{") + 1); sub(/}[^}]*$/, "", a); gsub(/^[ \t]+|[ \t]+$/, "", a)
        print a; exit
      }
    }
  ' "$DA_BINDS" 2>/dev/null
}

# How a bind should call an absolute binary: by name when PATH finds it, else
# by the package's launcher in /usr/bin (/opt/zen-browser-bin/zen-bin →
# zen-browser), else as is.
da_path_command() {
  local bin=$1 pkg cmd
  [ "$(command -v "${bin##*/}")" = "$bin" ] && { echo "${bin##*/}"; return; }
  pkg=$(da_owner_pkg "$bin")
  cmd=$([ -n "$pkg" ] && da_pkg_files "$pkg" | grep -m1 -E '^/usr/bin/[^/]+$')
  if [ -n "$cmd" ] && [ "$(command -v "${cmd##*/}")" = "$cmd" ]; then echo "${cmd##*/}"; else echo "$bin"; fi
}

# A desktop entry's Exec as a niri action: spawn "a" "b", or spawn-sh when it
# needs a shell. Absolute binaries go through da_path_command.
da_niri_action() {
  local exec w out="" first=1
  local -a words
  exec=$(awk -F'\t' -v id="$1" '$1 == id { print $5 }' "$DA_STATE/apps.tsv" |
    sed -E 's/ +%[fFuUdDnNickvm]//g; s/%%/%/g; s/^ +| +$//g')
  [ -n "$exec" ] || return 1
  if [[ $exec =~ [\"\'\$\;\&\|\<\>\`\\] ]]; then
    exec=${exec//\\/\\\\}
    printf 'spawn-sh "%s";' "${exec//\"/\\\"}"
    return
  fi
  read -ra words <<<"$exec"
  for w in "${words[@]}"; do
    [ $first = 1 ] && [[ $w == /* ]] && w=$(da_path_command "$w")
    first=0
    out+=" \"$w\""
  done
  printf 'spawn%s;' "$out"
}

da_owner_pkg() {
  if command -v pacman &>/dev/null; then pacman -Qqo "$1" 2>/dev/null
  else dpkg -S "$1" 2>/dev/null | head -1 | cut -d: -f1
  fi
}

da_pkg_files() {
  if command -v pacman &>/dev/null; then pacman -Qql "$1" 2>/dev/null
  else dpkg -L "$1" 2>/dev/null
  fi
}

da_role_category() {
  case $1 in
    terminal) echo TerminalEmulator ;;
    browser) echo WebBrowser ;;
    filemanager) echo FileManager ;;
  esac
}

# da_bind_app <key> <category> — the app the bind starts: an entry whose Exec
# runs the same command, else one from the same package (zen-browser →
# zen.desktop). Of several, the one in the role's category, shown in menus,
# with the Exec closest to the bind (kitty.desktop over kitty-open.desktop).
da_bind_app() {
  local line cmd path pkg ids=""
  line=$(da_bind_action "$1" | sed -E 's/^spawn(-sh)? +//; s/;$//; s/" "/ /g; s/^"|"$//g')
  cmd=${line%% *}
  [ -n "$cmd" ] || return 1
  da_bind_pick() {
    awk -F'\t' -v base="${cmd##*/}" -v line="$line" -v cat="$2" -v only="$1" '
      BEGIN { n = split(only, o, " "); for (i = 1; i <= n; i++) ok[o[i]] = 1 }
      {
        ex = $5; gsub(/ +%[a-zA-Z]/, "", ex); split(ex, w, " "); b = w[1]; sub(/.*\//, "", b)
        if (only != "" ? !($1 in ok) : b != base) next
        s = (index(";" $7 ";", ";" cat ";") ? 4 : 0) + ($3 ? 0 : 2) + (ex == line)
        if (!found || s > best) { best = s; id = $1; found = 1 }
      }
      END { if (found) print id }
    ' "$DA_STATE/apps.tsv"
  }
  da_bind_pick "" "$2" | grep . && return
  path=$(command -v "$cmd" 2>/dev/null) || return 1
  pkg=$(da_owner_pkg "$path")
  [ -n "$pkg" ] || return 1
  ids=$(awk -F'\t' 'FILENAME == ARGV[1] { want[$0] = 1; next } $6 in want { print $1 }' \
    <(da_pkg_files "$pkg" | grep '\.desktop$') "$DA_STATE/apps.tsv" | tr '\n' ' ')
  [ -n "$ids" ] && da_bind_pick "$ids" "$2"
}

da_bind_title() {
  awk -v key="$1" '
    !/^[ \t]*\/\// && match($0, /^[ \t]*[^ \t]+/) {
      k = substr($0, RSTART, RLENGTH); gsub(/[ \t]/, "", k)
      if (k == key && match($0, /hotkey-overlay-title="[^"]*"/)) { print substr($0, RSTART + 22, RLENGTH - 23); exit }
    }
  ' "$DA_BINDS" 2>/dev/null
}

# How terminals run a command in a window of a given class (= the app-id window
# rules match): binds like "kitty --class clipse -e 'clipse'" follow the
# terminal in its own syntax.
DA_TERM_FORMS=(
  "kitty|kitty --class %c -e %x"
  "alacritty|alacritty --class %c -e %x"
  "foot|foot --app-id %c %x"
  "wezterm|wezterm start --class %c -- %x"
)

# "<terminal>\t<class>\t<command>" of such a command line.
da_term_parse() {
  local line=$1 t
  t=${line%% *}
  t=${t##*/}
  case $t in
    kitty | alacritty) [[ $line =~ --class[=\ ]([^ ]+).*\ -e\ (.+)$ ]] ;;
    foot) [[ $line =~ --app-id[=\ ]([^ ]+)\ (.+)$ ]] ;;
    wezterm) [[ $line =~ --class[=\ ]([^ ]+).*\ --\ (.+)$ ]] ;;
    *) false ;;
  esac || return 1
  printf '%s\t%s\t%s\n' "$t" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

# Every bind (but the terminal's own) that runs a command in another terminal
# gets rewritten for this one. Prints what it changed.
da_sync_terminal_binds() {
  local id=$1 own=$2 new form key line t c x cmd title
  new=$(awk -F'\t' -v id="$id" '$1 == id { split($5, w, " "); print w[1] }' "$DA_STATE/apps.tsv")
  new=${new##*/}
  form=""
  for t in "${DA_TERM_FORMS[@]}"; do [ "${t%%|*}" = "$new" ] && form=${t#*|}; done
  while IFS=$'\t' read -r key line; do
    [ "$key" = "$own" ] && continue
    IFS=$'\t' read -r t c x < <(da_term_parse "$line") || continue
    [ "$t" = "$new" ] && continue
    if [ -z "$form" ]; then
      echo "$key: runs $t, $new has no known way to set a window class — left as is"
      continue
    fi
    cmd=${form//%c/$c}
    cmd=${cmd//%x/$x}
    cmd=${cmd//\\/\\\\}
    title=$(da_bind_title "$key")
    da_set_bind "$key" "$title" "spawn-sh \"${cmd//\"/\\\"}\";" && echo "$key → $new ($c)"
  done < <(awk '
    !/^[ \t]*\/\// && match($0, /^[ \t]*[^ \t]+/) && index($0, "{ spawn") {
      k = substr($0, RSTART, RLENGTH); gsub(/[ \t]/, "", k)
      a = substr($0, index($0, "{") + 1); sub(/}[^}]*$/, "", a); gsub(/^[ \t]+|[ \t;]+$/, "", a)
      if (a ~ /^spawn-sh /) { a = substr(a, 11, length(a) - 11); gsub(/\\"/, "\"", a) }
      else if (a ~ /^spawn /) { a = substr(a, 7); gsub(/" "/, " ", a); gsub(/^"|"$/, "", a) }
      else next
      print k "\t" a
    }
  ' "$DA_BINDS" 2>/dev/null)
}

# da_niri_replace <file> <new content file> — write it; if niri doesn't accept
# the config afterwards, the old content comes back. Keeps a missing last
# newline missing (awk ends every line).
da_niri_replace() {
  local file=$1 new=$2 old
  [ -n "$(tail -c1 "$file")" ] && truncate -s -1 "$new"
  cmp -s "$file" "$new" && return 0
  old=$(mktemp)
  cp "$file" "$old"
  cat "$new" >"$file"
  if command -v niri &>/dev/null && ! niri validate -c "$DA_CONFIG/niri/config.kdl" &>/dev/null; then
    cat "$old" >"$file"
    rm -f "$old"
    return 2
  fi
  rm -f "$old"
}

# The app-id an app's windows get (what window rules match): from its open
# window if there is one (niri msg windows: same binary), else StartupWMClass,
# else the desktop id (zen.desktop → zen).
da_app_id() {
  local id=$1 bin wm a p
  IFS=$'\t' read -r bin wm < <(awk -F'\t' -v id="$id" '$1 == id { split($5, w, " "); print w[1] "\t" $8 }' "$DA_STATE/apps.tsv")
  bin=$(readlink -f "$(command -v "$bin" 2>/dev/null)" 2>/dev/null)
  if [ -n "$bin" ] && command -v niri &>/dev/null && command -v jq &>/dev/null; then
    while IFS=$'\t' read -r a p; do
      [ "$(readlink -f "/proc/$p/exe" 2>/dev/null)" = "$bin" ] && { echo "$a"; return; }
    done < <(niri msg -j windows 2>/dev/null | jq -r '.[] | "\(.app_id)\t\(.pid)"')
  fi
  echo "${wm:-${id%.desktop}}"
}

# da_sync_rules <category> <desktop id> — window rules cover the role's app
# too: next to every match line of another app of the same kind (another
# terminal, browser) goes a copy with this app's app-id — (?i), anchors,
# r#""# and the rest of the line kept. Nothing is added where a line with the
# same rest already matches this app (r#"(?i)chrome"# covers google-chrome),
# so switching back and forth adds nothing. The comment above the rule gets
# the name added. Every file of DA_RULES that exists. Prints what was added.
da_sync_rules() {
  local cat=$1 id=$2 new name others tmp file rules
  # The DMS chooser opens no window of its own, rules have nothing to match.
  [ "$id" = dms-open.desktop ] && return 0
  new=$(da_app_id "$id")
  name=$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$DA_STATE/apps.tsv")
  name=${name% (${id%.desktop})}
  others=$(awk -F'\t' -v cat="$cat" -v id="$id" '
    $1 != id && $1 != "dms-open.desktop" && index(";" $7 ";", ";" cat ";") {
      n = $2; sub(/ \(.*\)$/, "", n); a = $8 != "" ? $8 : substr($1, 1, length($1) - 8)
      print $3 "\t" length(a) "\t" a "\t" n
    }
  ' "$DA_STATE/apps.tsv" | sort -t$'\t' -k1,1n -k2,2n | cut -f3-)  # shown apps, short ids first: kitty before kitty-open
  for rules in "${DA_RULES[@]}"; do
    file=$(readlink -f "$rules" 2>/dev/null) && [ -f "$file" ] || continue
    tmp=$(mktemp)
    awk -v new="$new" -v newname="$name" -v others="$others" '
      # Split a match line: P_ci (?i), P_s ^, P_e $, P_core the app-id text,
      # P_pos/P_len where the core sits, P_rest the line without the app-id.
      function parse(l,    t, a) {
        if (!match(l, /app-id=(r#)?"[^"]*"(#)?/)) return 0
        a = RSTART; t = substr(l, RSTART, RLENGTH)
        P_rest = substr(l, 1, a - 1) substr(l, a + RLENGTH)
        sub(/^app-id=(r#)?"/, "", t); sub(/"(#)?$/, "", t)
        P_pos = a + index(substr(l, a), "\"")
        P_ci = sub(/^\(\?i\)/, "", t); if (P_ci) P_pos += 4
        P_s = sub(/^\^/, "", t); if (P_s) P_pos++
        P_e = sub(/\$$/, "", t)
        P_core = t; P_len = length(t)
        return 1
      }
      # Does the parsed pattern match app-id x? (Escaped dots taken literally.)
      function hits(x,    p, i) {
        p = P_core; gsub(/\\\./, ".", p)
        if (P_ci) { p = tolower(p); x = tolower(x) }
        if (P_s && P_e) return x == p
        if (P_s) return index(x, p) == 1
        if (P_e) return (i = length(x) - length(p) + 1) > 0 && substr(x, i) == p
        return index(x, p) > 0
      }
      function ci_append(s, from, add,    i) {
        i = index(tolower(s), tolower(from))
        return i ? substr(s, 1, i - 1 + length(from)) ", " add substr(s, i + length(from)) : s
      }
      BEGIN {
        n = split(others, o, "\n")
        for (i = 1; i <= n; i++) { split(o[i], f, "\t"); if (f[1] != "" && f[1] != new) { oid[++no] = f[1]; oname[no] = f[2] } }
      }
      { line[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (line[i] !~ /^[ \t]*window-rule[ \t]*\{/) continue
          for (j = i + 1; j <= NR && line[j] !~ /^[ \t]*\}/; j++) ;
          delete covered
          for (k = i + 1; k < j; k++) if (line[k] ~ /^[ \t]*match/ && parse(line[k]) && hits(new)) covered[P_rest] = 1
          added = 0
          for (k = i + 1; k < j; k++) {
            if (line[k] !~ /^[ \t]*match/ || !parse(line[k]) || (P_rest in covered)) continue
            for (m = 1; m <= no && !hits(oid[m]); m++) ;
            if (m > no) continue
            covered[P_rest] = 1
            after[k] = after[k] "\n" substr(line[k], 1, P_pos - 1) new substr(line[k], P_pos + P_len)
            added = 1
            next_to[oid[m]] = 1
            oldname = oname[m]; oldid = oid[m]
          }
          # Only a comment that names the other app ("// Kitty (terminal)").
          cm = i > 1 ? tolower(line[i - 1]) : ""
          if (added && cm ~ /^[ \t]*\/\// && !index(cm, tolower(newname))) {
            if (oldname != "" && index(cm, tolower(oldname))) line[i - 1] = ci_append(line[i - 1], oldname, newname)
            else if (index(cm, tolower(oldid))) line[i - 1] = ci_append(line[i - 1], oldid, newname)
          }
          i = j
        }
        for (i = 1; i <= NR; i++) printf "%s%s\n", line[i], after[i]
        for (c in next_to) print c > "/dev/stderr"
      }
    ' "$file" >"$tmp" 2>"$tmp.changed"
    if da_niri_replace "$file" "$tmp"; then
      sed "s|.*|${rules##*/}: + $new next to &|" "$tmp.changed"
    else
      echo "${rules##*/}: niri didn't accept the change, kept the old ones"
    fi
    rm -f "$tmp" "$tmp.changed"
  done
}

# da_set_bind <key> <title> <action> — rewrite that bind's line in place
# (title and action; the key and the column of { stay). niri reloads the file
# itself; if it doesn't validate, the old line comes back.
da_set_bind() {
  local file tmp old nonl=""
  file=$(readlink -f "$DA_BINDS") && [ -f "$file" ] || return 1
  [ -n "$(tail -c1 "$file")" ] && nonl=1
  tmp=$(mktemp)
  old=$(mktemp)
  cp "$file" "$old"
  awk -v key="$1" -v title="${2//\"/\\\"}" -v action="$3" '
    !done && !/^[ \t]*\/\// && match($0, /^[ \t]*[^ \t]+[ \t]+/) {
      head = substr($0, 1, RLENGTH); k = head; gsub(/[ \t]/, "", k)
      rest = substr($0, RLENGTH + 1)
      if (k == key && match(rest, /^hotkey-overlay-title="[^"]*"[ \t]*/)) {
        new = "hotkey-overlay-title=\"" title "\""
        pad = RLENGTH - length(new); if (pad < 1) pad = 1
        print head new sprintf("%" pad "s", "") "{ " action " }"
        done = 1
        next
      }
    }
    { print }
    END { exit !done }
  ' "$file" >"$tmp" || { rm -f "$tmp" "$old"; return 1; }
  # awk ends every line; keep the file's last line as it was.
  [ -n "$nonl" ] && truncate -s -1 "$tmp"
  cat "$tmp" >"$file"
  if command -v niri &>/dev/null && ! niri validate -c "$DA_CONFIG/niri/config.kdl" &>/dev/null; then
    cat "$old" >"$file"
    rm -f "$tmp" "$old"
    return 2
  fi
  rm -f "$tmp" "$old"
}

# Point the role's bind at the app, unless it already starts it.
da_sync_bind() {
  local key=$1 label=$2 id=$3 cat=$4 name
  [ -n "$key" ] && [ -n "$id" ] && [ "$id" != dms-open.desktop ] || return 0
  [ -n "$(da_bind_action "$key")" ] || { print_error_message "$key: no bind line in $DA_BINDS"; return 1; }
  [ "$(da_bind_app "$key" "$cat")" = "$id" ] && return 0
  name=$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$DA_STATE/apps.tsv")
  name=${name% (${id%.desktop})}
  if da_set_bind "$key" "$label ($name)" "$(da_niri_action "$id")"; then
    print_success_message "$key → $name"
    [ "$cat" = TerminalEmulator ] && da_sync_terminal_binds "$id" "$key"
  else
    print_error_message "$key: niri didn't accept the new line, kept the old one"
    return 1
  fi
}


# ─── Default apps (roles) ─────────────────────────────────────────────────────

# da_role_app <role entry> — "id<TAB>same<TAB>total": the app of its first
# type (what DMS shows) and how many of its types use it too.
da_role_app() {
  local mimes
  if [ "${1%%|*}" = terminal ]; then
    printf '%s\t1\t1\n' "$(da_current_terminal)"
    return
  fi
  mimes=$(da_canon "${1##*|}" | tr '\n' ' ')
  awk -F'\t' -v list="$mimes" '
    BEGIN { n = split(list, m, " "); for (i = 1; i <= n; i++) want[m[i]] = i }
    $1 in want { id[want[$1]] = $2 }
    END { s = 0; for (i = 1; i <= n; i++) if (id[i] == id[1]) s++; printf "%s\t%d\t%d\n", id[1], s, n }
  ' "$DA_STATE/defaults.tsv"
}

# niri's binds decide terminal, browser and file manager: whatever a bind starts
# becomes that role's default (the whole group of types), so editing binds.kdl
# by hand carries over. A role set to the DMS chooser stays — no bind can ask.
# What changed is kept in $DA_STATE/synced for the header.
da_sync_from_niri() {
  local r role label key mimes id cur same total name
  : >"$DA_STATE/synced"
  for r in "${DA_ROLES[@]}"; do
    IFS='|' read -r role label key mimes <<<"$r"
    [ -n "$key" ] || continue
    id=$(da_bind_app "$key" "$(da_role_category "$role")") && [ -n "$id" ] || continue
    name=$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$DA_STATE/apps.tsv")
    name=${name% (${id%.desktop})}
    # The bind's title says what it starts: "Terminal (Alacritty)".
    if [ "$(da_bind_title "$key")" != "$label ($name)" ]; then
      da_set_bind "$key" "$label ($name)" "$(da_bind_action "$key")" &&
        echo "$key title → $label ($name)" >>"$DA_STATE/synced"
    fi
    [ "$role" = terminal ] && da_sync_terminal_binds "$id" "$key" >>"$DA_STATE/synced"
    da_sync_rules "$(da_role_category "$role")" "$id" >>"$DA_STATE/synced"
    IFS=$'\t' read -r cur same total < <(da_role_app "$r")
    [ "$cur" = dms-open.desktop ] && continue
    [ "$id" = "$cur" ] && [ "$same" = "$total" ] && continue
    if [ "$role" = terminal ]; then
      da_write_terminal "$id"
    else
      # shellcheck disable=SC2086  # a list of types
      da_write "$id" $mimes
      da_build_defaults
    fi
    echo "$label → $name ($key)" >>"$DA_STATE/synced"
  done
}

da_roles_render() {
  local r role label key mimes id same total name action bind cmd extra bapp
  local G=$'\e[32m' Y=$'\e[33m' E=$'\e[31m' D=$'\e[90m' R=$'\e[0m'
  for r in "${DA_ROLES[@]}"; do
    IFS='|' read -r role label key mimes <<<"$r"
    IFS=$'\t' read -r id same total < <(da_role_app "$r")
    name=$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$DA_STATE/apps.tsv")
    extra=""
    [ "$same" -lt "$total" ] && extra="$same/$total types"
    name=$(printf '%-34s %-11s' "${name:-nothing}" "$extra")
    [ -n "$extra" ] && name=${name/"$extra"/"$Y$extra$R"}
    [ -n "$id" ] || name="$D$name$R"
    bind=""
    if [ -n "$key" ]; then
      action=$(da_bind_action "$key")
      bapp=$(da_bind_app "$key" "$(da_role_category "$role")")
      cmd=${action#spawn*\"}
      cmd=${cmd%\";}
      cmd=${cmd//\" \"/ }
      if [ -z "$action" ]; then bind="${E}$key: no bind$R"
      elif [ -z "$bapp" ]; then bind="${E}$key runs $cmd — no app found for it$R"
      elif [ "$bapp" = "$id" ]; then bind="${G}$key ✓$R"
      else bind="${D}$key runs $cmd$R"
      fi
    fi
    printf 'R:%s\t%-14s → %s  %s\n' "$role" "$label" "$name" "$bind"
  done
}

da_role_preview() {
  local r role label key mimes id m owner
  local T=$'\e[1;36m' L=$'\e[90m' R=$'\e[0m' rule=$'\e[90m────────────────────────────────\e[0m'
  for r in "${DA_ROLES[@]}"; do [ "${r%%|*}" = "${1#R:}" ] && break; done
  IFS='|' read -r role label key mimes <<<"$r"
  echo "$T$label$R"
  echo "$rule"
  case $role in
    terminal)
      echo "No file type to attach a terminal to, so it is a list:"
      echo "  $DA_TERMINALS (first installed one wins)"
      echo
      echo "${T}Used by$R"
      echo "  • DMS: apps with Terminal=true (Neovim, btop, htop) started from"
      echo "    the launcher or Open with, and its Settings → Default apps"
      echo "  • xdg-terminal-exec: $(command -v xdg-terminal-exec &>/dev/null && echo installed || echo "${L}not installed$R")"
      echo "  • niri: $key — the bind decides: what it starts becomes the terminal"
      echo "    on every start of defapps, and picking one here rewrites it"
      echo "${T}Not used by$R"
      echo "  • GLib apps without xdg-terminal-exec (they try their own list)"
      echo "  • \"Open terminal here\" in file managers (their own setting)"
      ;;
    filemanager)
      echo "Folders are a type too, so this is mimeapps.list:"
      echo "  inode/directory, file:, sftp: links"
      echo
      echo "${T}Used by$R"
      echo "  • xdg-open of a folder, folders from the DMS launcher, \"open folder\""
      echo "    in download notifications, Open with on a folder"
      echo "  • niri: $key — the bind decides, like for the terminal"
      echo "${T}Not used by$R"
      echo "  • \"Show in folder\" in browsers, VS Code, Telegram: that is the D-Bus"
      echo "    service org.freedesktop.FileManager1, which whatever file manager"
      echo "    owns it answers."
      owner=$(busctl --user status org.freedesktop.FileManager1 2>/dev/null | sed -n 's/^Comm=//p')
      echo "    Now: ${owner:-${L}nobody running$R}. Can provide it:"
      grep -l '^Name=org.freedesktop.FileManager1' /usr/share/dbus-1/services/*.service 2>/dev/null |
        xargs -r sed -n 's/^Exec=\([^ ]*\).*/      \1/p'
      echo "    If none is running, D-Bus starts one of them — which one is not set."
      ;;
    browser)
      echo "Links and web pages in mimeapps.list: https:, http:, .html, .xhtml."
      echo "To open .html in an editor but links in the browser, change .html in"
      echo "File types afterwards."
      echo "  • niri: $key — the bind decides: what it starts becomes the browser on"
      echo "    every start of defapps, and picking one here rewrites it."
      echo "    Exception: Ask every time (DMS chooser) stays, a bind can't ask."
      ;;
    editor)
      echo "Text and code types in mimeapps.list (the ones DMS sets)."
      echo "Mod+C stays VS Code whatever is chosen here."
      ;;
    *) echo "Every type of the group in mimeapps.list." ;;
  esac
  [ -n "$key" ] && echo && echo "${T}Bind now$R" && echo "$rule" && echo "  $key { $(da_bind_action "$key") }"
  if [ -n "$mimes" ]; then
    echo
    echo "${T}Types$R"
    echo "$rule"
    for m in $(da_canon "$mimes"); do
      id=$(awk -F'\t' -v m="$m" '$1 == m { print $2 }' "$DA_STATE/defaults.tsv")
      printf '  %-34s %s\n' "$m" "$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$DA_STATE/apps.tsv")"
    done
  fi
}

da_roles() {
  local row role r label bkey mimes id header
  fzf_base_opts "Default apps" "$(fzf_keys "j/k ↑↓" move Enter "pick the app" Esc back)
Terminal, browser, file manager follow niri's binds: edit binds.kdl and they change here on the next start"
  while true; do
    header="Writes $DA_MIMEAPPS · terminal: $DA_TERMINALS"
    [ -s "$DA_STATE/synced" ] && header+=$'\n'"Taken from niri binds: $(paste -sd ';' "$DA_STATE/synced" | sed 's/;/ · /g')"
    row=$(da_roles_render | SHELL=/bin/bash fzf "${FZF_OPTS[@]}" --header "$header" \
      --preview "$DA_CMD da_role_preview {1}" --preview-window 'right,50%,wrap' \
      --bind "space:accept" | cut -f1) || return 0
    [ -n "$row" ] || return 0
    role=${row#R:}
    for r in "${DA_ROLES[@]}"; do [ "${r%%|*}" = "$role" ] && break; done
    IFS='|' read -r role label bkey mimes <<<"$r"
    if [ "$role" = terminal ]; then
      id=$(da_pick_app --terminal) && [ -n "$id" ] || continue
      da_write_terminal "$id"
    else
      # shellcheck disable=SC2086  # a list of types
      id=$(da_pick_app $(da_canon "$mimes")) && [ -n "$id" ] || continue
      # shellcheck disable=SC2086
      da_write "$id" $mimes
      da_build_defaults
    fi
    da_sync_bind "$bkey" "$label" "$id" "$(da_role_category "$role")"
    [ -n "$bkey" ] && da_sync_rules "$(da_role_category "$role")" "$id" | while IFS= read -r l; do print_success_message "$l"; done
  done
}


# ─── File types ───────────────────────────────────────────────────────────────

# Known type of an extension: user database first, then the system one.
da_ext_mime() {
  awk -F: -v g="*.$1" '!/^#/ && tolower($3) == g { print $2; exit }' <(da_mime_cat globs2)
}

da_xml_escape() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g' <<<"$1"
}

# da_custom_write <ext> [<mime> <comment>] — remove the extension's line, and
# with a type add it back. Comment empty = attach to an existing type.
da_custom_write() {
  local ext=$1 mime=$2 comment=$3 line
  # The file lives in the dotfiles, the mime dir links to it.
  if [ ! -e "$DA_USER_PKG" ]; then
    mkdir -p "$(dirname "$DA_USER_PKG")" "$DA_DOTS"
    [ -f "$DA_DOTS/defapps.xml" ] || printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
      '<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">' '</mime-info>' >"$DA_DOTS/defapps.xml"
    ln -s "$DA_DOTS/defapps.xml" "$DA_USER_PKG"
  fi
  grep -vF "pattern=\"*.$ext\"" "$DA_USER_PKG" >"$DA_USER_PKG.tmp"
  if [ -n "$mime" ]; then
    line="  <mime-type type=\"$mime\">${comment:+<comment>$(da_xml_escape "$comment")</comment>}<glob pattern=\"*.$ext\" weight=\"60\"/></mime-type>"
    awk -v line="$line" '/^<\/mime-info>/ { print line } { print }' "$DA_USER_PKG.tmp" >"$DA_USER_PKG"
  else
    cat "$DA_USER_PKG.tmp" >"$DA_USER_PKG"
  fi
  rm -f "$DA_USER_PKG.tmp"
  update-mime-database "$DA_USER_MIME" &>/dev/null
}

da_pick_existing_type() {
  awk -F'\t' '$4 != 1 && $3 != "" && !seen[$2]++ { printf "%s\t%-40s \033[90m%s\033[0m\n", $2, $2, $3 }' "$DA_STATE/types.tsv" |
    SHELL=/bin/bash fzf --ansi --delimiter '\t' --with-nth 2 --layout reverse --height 100% --style full \
      --list-label " Open it like which type? " --prompt "type> " \
      --preview "$DA_CMD --preview M:x:{1}" --preview-window right,45%,wrap |
    cut -f1
}

da_add_ext() {
  local ext known how mime comment id
  ext=$(gum input --header "Extension (without the dot)" --placeholder "conf" </dev/tty) || return 1
  ext=${ext#.}
  ext=${ext,,}
  [[ $ext =~ ^[a-z0-9][a-z0-9._+-]*$ ]] || { print_error_message "Not an extension: $ext"; return 1; }
  known=$(da_ext_mime "$ext")
  if [ -n "$known" ]; then
    how=$(gum choose --header ".$ext is already $known" \
      "Pick an app for $known — every .$ext file follows it" \
      "Own type — split .$ext off into a type of its own" \
      "Cancel" </dev/tty) || return 1
    case $how in
      Pick*)
        id=$(da_pick_app "$known") && [ -n "$id" ] && da_write "$id" "$known"
        return
        ;;
      Cancel) return 1 ;;
    esac
    how=own
  else
    how=$(gum choose --header ".$ext is unknown to the system" \
      "Own type — a new type just for .$ext, with any app" \
      "Like an existing type — e.g. open it as text/plain" </dev/tty) || return 1
    how=${how%% *}
  fi
  if [ "${how,,}" = own ]; then
    mime="application/x-$ext"
    grep -qxF "$mime" <(da_mime_cat types) && mime="application/x-defapps-$ext"
    comment=$(gum input --header "Description" --value "${ext^^} file" </dev/tty) || return 1
    da_custom_write "$ext" "$mime" "$comment"
  else
    mime=$(da_pick_existing_type) && [ -n "$mime" ] || return 1
    da_custom_write "$ext" "$mime" ""
  fi
  print_success_message ".$ext → $mime"
  da_build_types
  da_build_defaults
  gum confirm "Pick the app for .$ext ($mime) now?" </dev/tty || return 0
  id=$(da_pick_app "$mime") && [ -n "$id" ] && da_write "$id" "$mime"
}

da_types() {
  local out key row pos=1 id ext mime
  local -a targets
  fzf_base_opts "File types" "$(fzf_keys "j/k ↑↓" move "Enter" "fold / pick app" Space tick "Alt+Enter" "app for ticked / whole category" "/ Ctrl-F" search)
$(fzf_keys Ctrl-R "reset to system" Ctrl-D "remove your extension" Esc back Ctrl-/ "hide preview")
plain = chosen by you   "$'\e[90m'"(system: …)"$'\e[0m'" = nobody chose   "$'\e[31m'"✗ missing"$'\e[0m'" = chosen app not installed"
  while true; do
    out=$(da_render | SHELL=/bin/bash fzf "${FZF_OPTS[@]}" \
      --header "$(da_header)" --expect alt-enter,ctrl-r,ctrl-d \
      --preview "$DA_CMD --preview {1}" --preview-window 'right,45%,wrap' \
      --bind "start:pos($pos)" \
      --bind "space:transform:$DA_CMD --toggle {1}" \
      --bind "tab:transform:$DA_CMD --tab {1}" \
      --bind "enter:transform:$DA_CMD --enter {1}" \
      --bind "change:reload-sync($DA_CMD --render)") || return 0
    key=$(sed -n 1p <<<"$out")
    row=$(sed -n 2p <<<"$out" | cut -f1)
    pos=$(da_render | fzf_visible_keys | fzf_pos_of "$row")

    case $key in
      "")
        if [ "$row" = A:add ]; then
          grep -qxF "$DA_CUSTOM" "$DA_STATE/open" || echo "$DA_CUSTOM" >>"$DA_STATE/open"
          da_add_ext
          da_build_defaults
          continue
        fi
        mapfile -t targets < <(da_row_mimes "$row")
        ;;
      alt-enter)
        if [ -s "$DA_STATE/checked" ]; then
          mapfile -t targets <"$DA_STATE/checked"
        else
          mapfile -t targets < <(da_row_mimes "H:$(da_row_cat "$row")")
        fi
        ;;
      ctrl-r)
        if [ -s "$DA_STATE/checked" ]; then mapfile -t targets <"$DA_STATE/checked"
        else mapfile -t targets < <(da_row_mimes "$row")
        fi
        ;;
      ctrl-d)
        [[ $row == X:* ]] || continue
        ext=${row#X:}
        mime=${ext#*|}
        ext=${ext%%|*}
        gum confirm "Remove .$ext ($mime) from your extensions?" </dev/tty || continue
        da_custom_write "$ext"
        [[ $mime == application/x-$ext || $mime == application/x-defapps-$ext ]] && da_write "" "$mime"
        da_build_types
        da_build_defaults
        continue
        ;;
    esac
    [ ${#targets[@]} -gt 0 ] || continue

    if [ "$key" = ctrl-r ]; then
      gum confirm "Reset ${#targets[@]} type(s) to what the system picks?" </dev/tty || continue
      da_write "" "${targets[@]}"
    else
      id=$(da_pick_app "${targets[@]}")
      [ -n "$id" ] || continue
      da_write "$id" "${targets[@]}"
    fi
    : >"$DA_STATE/checked"
    da_build_defaults
  done
}


# ─── Dotfiles ─────────────────────────────────────────────────────────────────

# Keep Dotfiles/defapps in step with this machine for the installer step:
# [Default Applications] and the terminal list are copied there (entries for
# apps not installed here, kept from another PC, stay), defapps.xml is linked.
da_mirror() {
  local tmp
  mkdir -p "$DA_DOTS"
  if [ -f "$DA_USER_PKG" ] && [ ! -L "$DA_USER_PKG" ] && [ ! -e "$DA_DOTS/defapps.xml" ]; then
    mv "$DA_USER_PKG" "$DA_DOTS/defapps.xml" && ln -s "$DA_DOTS/defapps.xml" "$DA_USER_PKG"
  fi
  tmp=$(mktemp)
  awk -F= -v appsf="$DA_STATE/apps.tsv" '
    BEGIN { while ((getline l < appsf) > 0) { split(l, a, "\t"); inst[a[1]] = 1 } }
    FILENAME == ARGV[1] { here[$1] = 1; out[++n] = $0; next }
    !($1 in here) { split($2, ids, ";"); if (!(ids[1] in inst)) out[++n] = $0 }
    END { print "[Default Applications]"; for (i = 1; i <= n; i++) print out[i] }
  ' <(awk '/^\[/ { on = ($0 == "[Default Applications]"); next } on && index($0, "=")' "$DA_MIMEAPPS" 2>/dev/null) \
    <(awk '/^\[/ { on = ($0 == "[Default Applications]"); next } on && index($0, "=")' "$DA_DOTS/mimeapps.list" 2>/dev/null) >"$tmp"
  cmp -s "$tmp" "$DA_DOTS/mimeapps.list" || cat "$tmp" >"$DA_DOTS/mimeapps.list"
  rm -f "$tmp"
  [ -f "$DA_TERMINALS" ] && ! cmp -s "$DA_TERMINALS" "$DA_DOTS/xdg-terminals.list" && cp "$DA_TERMINALS" "$DA_DOTS/xdg-terminals.list"
  return 0
}

# Installer side: put Dotfiles/defapps back on this machine.
da_restore_types() {
  [ -f "$DA_DOTS/defapps.xml" ] || { echo ":: No extensions saved yet ($DA_DOTS/defapps.xml)"; return 0; }
  create_symlink "$DA_DOTS/defapps.xml" "$DA_USER_PKG" && update-mime-database "$DA_USER_MIME"
}

# One app under its Arch package's and its Ubuntu package's or flatpak's desktop
# id, so a default saved on one machine finds the app on the other.
declare -A DA_SAME_APP=()
for _pair in \
  "vesktop.desktop dev.vencord.Vesktop.desktop" \
  "com.microsoft.VSCode.desktop code.desktop" \
  "obsidian.desktop md.obsidian.Obsidian.desktop" \
  "google-chrome.desktop com.google.Chrome.desktop" \
  "jetbrains-idea.desktop com.jetbrains.IntelliJ-IDEA-Ultimate.desktop"; do
  read -r _a _b <<<"$_pair"
  DA_SAME_APP[$_a]=$_b DA_SAME_APP[$_b]=$_a
done
unset _pair _a _b

# The saved defaults go into mimeapps.list for the apps installed here; the
# rest of the file stays. Lists what was skipped.
da_restore_defaults() {
  local src="$DA_DOTS/mimeapps.list" mime ids id i
  local -A by_id=()
  local -a skipped=()
  [ -f "$src" ] || { echo ":: No defaults saved yet ($src)"; return 0; }
  DA_STATE=$(mktemp -d)
  da_build_apps
  while IFS='=' read -r mime ids; do
    [[ -z $mime || $mime == \[* || -z $ids ]] && continue
    id=""
    IFS=';' read -ra i <<<"$ids"
    for id in "${i[@]}"; do
      grep -q "^${id}"$'\t' "$DA_STATE/apps.tsv" && break
      id=${DA_SAME_APP[$id]:-}
      [ -n "$id" ] && grep -q "^${id}"$'\t' "$DA_STATE/apps.tsv" && break
      id=""
    done
    if [ -n "$id" ]; then by_id[$id]+=" $mime"; else skipped+=("$mime → ${ids%;}"); fi
  done <"$src"
  for id in "${!by_id[@]}"; do
    # shellcheck disable=SC2086  # a list of types
    da_write "$id" ${by_id[$id]}
    echo ":: $id:${by_id[$id]}"
  done
  [ ${#skipped[@]} -gt 0 ] && printf ':: Skipped, app not installed: %s\n' "${skipped[@]}"
  rm -rf "$DA_STATE"
}

da_restore_terminal() {
  [ -f "$DA_DOTS/xdg-terminals.list" ] || { echo ":: No terminal saved yet"; return 0; }
  mkdir -p "$(dirname "$DA_TERMINALS")"
  cat "$DA_DOTS/xdg-terminals.list" >"$DA_TERMINALS"
  echo ":: Terminal order: $(paste -sd ' ' "$DA_TERMINALS")"
}


default_apps() {
  require_gum defapps || return 1
  fzf_ready || { echo ":: needs fzf >= $FZF_MIN_VERSION" >&2; return 1; }
  DA_STATE=$(mktemp -d)
  export DA_STATE
  # On the way out (Esc in the menu exits too) the choices go to the dotfiles.
  trap 'da_mirror; rm -rf "$DA_STATE"' EXIT
  : >"$DA_STATE/checked"
  : >"$DA_STATE/open"
  da_build
  da_sync_from_niri
  da_mirror
  [ -s "$DA_STATE/synced" ] && sed 's/^/:: Taken from niri binds: /' "$DA_STATE/synced"
  menu "🚪 Exit" \
    "Default apps — terminal, browser, file manager, editor, viewers…|da_roles" \
    "File types — every type by extension, links, your own extensions|da_types"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then "$@"; fi
