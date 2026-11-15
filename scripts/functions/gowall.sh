#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# gw: every gowall feature behind gum menus, with a preview before anything is
# saved. Edits of one image stack up in a temp dir; ~/Pictures only gets the
# result when you pick Save. Commands that can't write to stdout (compress,
# upscale, stack, gif) go through a temp file, and so does bg: its first-run
# download prompt would otherwise end up inside the image.

GW_OUT_DIR="$HOME/Pictures/gowall"

gw_tmpdir() {
  [ -n "$GW_TMP" ] && return
  GW_TMP=$(mktemp -d -t gw.XXXXXX)
  trap 'rm -rf "$GW_TMP"' EXIT
}

# ─── Prompts ──────────────────────────────────────────────────────────────────

# Description box shown before an action's questions; one argument per line.
gw_about() {
  gum style --border rounded --border-foreground 212 --padding "0 1" --width 80 "$@"
}

# gw_ask <var> <question> <default> — free input, prefilled with the default.
gw_ask() {
  local __v
  __v=$(gum input --header "$2" --value "$3" --width 80 </dev/tty) || return 1
  printf -v "$1" '%s' "$__v"
}

# gw_choose <var> <question> "value — explanation"... — var gets the part
# before " — ", so the explanation is only for reading.
gw_choose() {
  local __var=$1 __h=$2 __v
  shift 2
  __v=$(gum choose --header "$__h" --height 20 "$@" </dev/tty) || return 1
  printf -v "$__var" '%s' "${__v%% — *}"
}

gw_yes() {
  gum confirm "$1" </dev/tty
}

gw_expand() {
  printf '%s' "${1/#\~/$HOME}"
}

# ─── Picking files ────────────────────────────────────────────────────────────

# gw_find <root> <ext>... — files with these extensions under root, sorted.
gw_find() {
  local root=$1 args=() e
  shift
  for e in "$@"; do args+=(-e "$e"); done
  fd -t f -i "${args[@]}" . "$root" 2>/dev/null | sort
}

# gw_browse <root> <multi:0|1> <ext>... — fzf over the files; kitty shows the
# image next to the list.
gw_browse() {
  local root=$1 multi=$2 opts
  shift 2
  opts=(--height 90% --layout reverse --prompt "$(basename "$root")/ " --info inline)
  if [ "$multi" = 1 ]; then
    opts+=(--multi --header "Tab: mark (order of marking = order of images) · Enter: done")
  else
    opts+=(--header "Enter: pick")
  fi
  [ -n "$KITTY_WINDOW_ID" ] && opts+=(--preview-window right,55% --preview \
    'kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" {}')
  gw_find "$root" "$@" | fzf "${opts[@]}"
}

# gw_pick_file <var> <what> <ext>... — current wallpaper, clipboard, a browse
# with fzf, or a typed path.
gw_pick_file() {
  local __var=$1 what=$2 __p __src wall mime opts=()
  shift 2
  if [[ " $* " == *" png "* ]]; then
    wall=$(dms ipc call wallpaper get 2>/dev/null)
    [ -f "$wall" ] && opts+=("Current wallpaper — $wall")
    mime=$(wl-paste -l 2>/dev/null | grep -m1 '^image/')
    [ -n "$mime" ] && opts+=("Clipboard — the image you copied or screenshotted last")
  fi
  opts+=("Browse ~/Pictures — search by name, preview in kitty"
    "Browse another folder"
    "Type a path")
  gw_choose __src "Which $what?" "${opts[@]}" || return 1
  case $__src in
    "Current wallpaper") __p=$wall ;;
    Clipboard)
      gw_tmpdir
      __p="$GW_TMP/clipboard.${mime#image/}"
      wl-paste -t "$mime" >"$__p" || return 2
      ;;
    "Browse ~/Pictures") __p=$(gw_browse "$HOME/Pictures" 0 "$@") ;;
    "Browse another folder")
      gw_ask __p "Folder" "$HOME/" || return 1
      __p=$(gw_browse "$(gw_expand "$__p")" 0 "$@")
      ;;
    "Type a path") gw_ask __p "Path to the $what" "$HOME/" || return 1 ;;
  esac
  __p=$(gw_expand "$__p")
  [ -f "$__p" ] || { print_error_message "No such file"; return 1; }
  printf -v "$__var" '%s' "$__p"
}

gw_pick_image() {
  gw_pick_file "$1" image png jpg jpeg webp avif
}

# gw_pick_images <array var> — several images marked in fzf, or every image
# of one folder (sorted by name).
gw_pick_images() {
  local -n __arr=$1
  local how dir
  gw_choose how "Which images?" \
    "Mark them — pick from ~/Pictures with Tab" \
    "Mark them in another folder" \
    "A whole folder — every image directly inside it" || return 1
  case $how in
    "Mark them") mapfile -t __arr < <(gw_browse "$HOME/Pictures" 1 png jpg jpeg webp avif) ;;
    "Mark them in another folder")
      gw_ask dir "Folder" "$HOME/" || return 1
      mapfile -t __arr < <(gw_browse "$(gw_expand "$dir")" 1 png jpg jpeg webp avif)
      ;;
    "A whole folder")
      gw_ask dir "Folder" "$HOME/Pictures/" || return 1
      mapfile -t __arr < <(fd -t f -i -d 1 -e png -e jpg -e jpeg -e webp -e avif . "$(gw_expand "$dir")" | sort)
      ;;
  esac
  [ ${#__arr[@]} -gt 0 ] || { print_error_message "No images picked"; return 1; }
}

# --batch is a CSV list, so quote every path (commas in names stay intact).
gw_batch_arg() {
  local out="" f
  for f in "$@"; do out+="${out:+,}\"$f\""; done
  printf '%s' "$out"
}

# ─── Results ──────────────────────────────────────────────────────────────────

gw_show() {
  echo ":: Preview opened — close it (q) to continue"
  if command -v swayimg &>/dev/null; then
    swayimg "$1" &>/dev/null
  else
    kitten icat "$1"
    read -rsn1 -p ":: Press any key" </dev/tty
    echo
  fi
}

gw_info() {
  printf '%s, %s' "$(magick identify -format '%wx%h' "$1[0]" 2>/dev/null)" "$(du -h "$1" | cut -f1)"
}

# Give a file the extension of what it really is (stdout output has no name).
gw_fix_ext() {
  local f=$1 ext
  case $(file -b --mime-type "$f") in
    image/png) ext=png ;;
    image/jpeg) ext=jpg ;;
    image/webp) ext=webp ;;
    image/avif) ext=avif ;;
    image/gif) ext=gif ;;
    *) printf '%s' "$f"; return ;;
  esac
  [ "${f##*.}" = "$ext" ] && { printf '%s' "$f"; return; }
  mv "$f" "${f%.*}.$ext"
  printf '%s' "${f%.*}.$ext"
}

# gw_save <file> <suggested name> — copy to a path you confirm; prints it.
gw_save() {
  local f=$1 dest
  gw_ask dest "Save as" "$GW_OUT_DIR/$2.${f##*.}" || return 1
  dest=$(gw_expand "$dest")
  if [ -e "$dest" ] && ! gw_yes "$dest exists. Overwrite?"; then
    return 1
  fi
  mkdir -p "$(dirname "$dest")" && cp "$f" "$dest" || return 2
  print_success_message "Saved $(basename "$dest")" >&2
  printf '%s' "$dest"
}

gw_set_wallpaper() {
  dms ipc call wallpaper set "$1" >/dev/null && print_success_message "Wallpaper set"
}

# gw_finish <file> <suggested name> — what to do with a finished image.
gw_finish() {
  local f=$1 name=$2 act saved=""
  while true; do
    gw_choose act "Result: $(gw_info "$f")${saved:+ · saved to $saved}" \
      "Save — copy it to ~/Pictures/gowall (or a path you type)" \
      "Save and set as wallpaper — through DMS" \
      "Copy to clipboard — paste it into a chat or an editor" \
      "Preview again" \
      "Done — anything unsaved is deleted" || return 0
    case $act in
      Save) saved=$(gw_save "$f" "$name") ;;
      "Save and set as wallpaper") saved=$(gw_save "$f" "$name") && gw_set_wallpaper "$saved" ;;
      "Copy to clipboard") wl-copy -t "$(file -b --mime-type "$f")" <"$f" && print_success_message "Copied" ;;
      "Preview again") gw_show "$f" ;;
      Done) return 0 ;;
    esac
  done
}

# ─── Edit operations ──────────────────────────────────────────────────────────
#
# Each gw_op_* explains itself, asks its settings and fills OP_* for
# gw_apply / gw_apply_batch:
#   OP_SUB     gowall subcommand words (effects br)
#   OP_FLAGS   its flags
#   OP_TAG     short name for the saved file (nord, br1.2)
#   OP_DESC    what was done, for History (Brightness ×1.2)
#   OP_STDOUT  1 = write to stdout, 0 = gowall writes a file itself
#   OP_EXT     extension of that file (empty = same as the input)
# $1 is the image the op runs on (for defaults like its size).

gw_op_reset() {
  OP_SUB=() OP_FLAGS=() OP_TAG="" OP_DESC="" OP_STDOUT=1 OP_EXT=""
}

# gw_pick_theme <var> — gowall's themes (incl. custom ones) or a JSON file.
gw_pick_theme() {
  local __t themes
  mapfile -t themes < <(gowall list)
  __t=$(gum filter --header "Theme (type to search)" --height 20 \
    "${themes[@]}" "JSON file — a theme file of your own" </dev/tty) || return 1
  if [ "$__t" = "JSON file — a theme file of your own" ]; then
    gw_ask __t "Path to the theme JSON" "$HOME/" || return 1
    __t=$(gw_expand "$__t")
  fi
  printf -v "$1" '%s' "$__t"
}

gw_op_theme() {
  gw_about "Recolor to a theme" "" \
    "Every pixel moves to the closest color of the chosen palette (catppuccin," \
    "nord, gruvbox, ...): shapes and light stay, only the theme's colors remain." \
    "" \
    "If the wrong areas get the dark colors, undo, run Invert first and recolor" \
    "again — the result is completely different." \
    "Own themes: add them under 'themes:' in ~/.config/gowall/config.yml, or pick" \
    "a JSON file: {\"name\": \"x\", \"colors\": [\"#1e1e2e\", ...]}."
  local t
  gw_pick_theme t || return 1
  OP_SUB=(convert) OP_FLAGS=(-t "$t") OP_TAG=$(basename "$t" .json)
  OP_DESC="Theme $OP_TAG"
}

gw_op_replace() {
  gw_about "Replace a color" "" \
    "Swaps one exact color for another, e.g. a too bright background." \
    "Get the color with a color picker (DMS, or the Palette menu in gw)." \
    "" \
    "Threshold: how close a pixel must be to count as that color." \
    "  0 = nothing changes; 10-40 also catches the near shades around edges and" \
    "  in gradients; higher = more of the image gets replaced."
  local from to th
  gw_ask from "Color to replace (hex)" "#" || return 1
  gw_ask to "Replace it with (hex)" "#" || return 1
  gw_ask th "Threshold (empty = gowall's default)" "20" || return 1
  OP_SUB=(convert) OP_FLAGS=(-r "$from,$to${th:+,$th}") OP_TAG="replace"
  OP_DESC="Replace $from → $to${th:+, threshold $th}"
}

gw_op_invert() {
  gw_about "Invert colors" "" \
    "Every color becomes its opposite: white ↔ black, blue ↔ orange." \
    "Useful before Recolor: an inverted picture maps to the theme differently."
  OP_SUB=(invert) OP_TAG="invert" OP_DESC="Invert"
}

gw_op_format() {
  gw_about "Change format" "" \
    "Same picture, another file type. Nothing else changes."
  local f
  gw_choose f "Format" \
    "png — lossless, keeps transparency, biggest files" \
    "jpg — small, no transparency, slight quality loss" \
    "webp — smaller than jpg, keeps transparency" \
    "avif — smallest, keeps transparency, newer (some apps can't open it)" || return 1
  OP_SUB=(convert) OP_FLAGS=(-f "$f") OP_TAG="$f" OP_DESC="Format $f"
}

gw_op_brightness() {
  gw_about "Brightness" "" \
    "Multiplies every pixel's brightness by the factor (above 0, up to 10)." \
    "  1.2 = 20% brighter · 0.8 = 20% darker · 1 = unchanged" \
    "Big values blow the light areas out to pure white."
  local f
  gw_ask f "Factor" "1.2" || return 1
  OP_SUB=(effects br) OP_FLAGS=(-f "$f") OP_TAG="br$f" OP_DESC="Brightness ×$f"
}

gw_op_contrast() {
  gw_about "Contrast" "" \
    "normal — stretches all tones evenly away from the middle. Strong values" \
    "  clip highlights to white and shadows to black." \
    "sigmoid — an S-curve: punchier mid-tones, highlights and shadows stay" \
    "  smooth. Midpoint = the brightness the curve pivots around (0.5 = middle)."
  local m f p
  gw_choose m "Mode" \
    "normal — even, simple" \
    "sigmoid — S-curve, softer on highlights and shadows" || return 1
  if [ "$m" = normal ]; then
    gw_ask f "Amount, -100 to 100 (negative = flatter, positive = more contrast)" "20" || return 1
    OP_FLAGS=(-m normal -f "$f") OP_TAG="contrast$f" OP_DESC="Contrast $f"
  else
    gw_ask f "Strength, -10 to 10 (negative = flatter)" "5" || return 1
    gw_ask p "Midpoint, 0 to 1" "0.5" || return 1
    OP_FLAGS=(-m sigmoid -s "$f" -p "$p") OP_TAG="sigmoid$f" OP_DESC="Contrast sigmoid $f, mid $p"
  fi
  OP_SUB=(effects contrast)
}

gw_op_gamma() {
  gw_about "Gamma" "" \
    "Brightens or darkens the mid-tones; pure black and white stay as they are," \
    "so it looks more natural than Brightness." \
    "  above 1 = lighter mid-tones (1.5) · below 1 = darker (0.7) · 1 = unchanged"
  local g
  gw_ask g "Gamma (above 0)" "1.3" || return 1
  OP_SUB=(effects gamma) OP_FLAGS=(-g "$g") OP_TAG="gamma$g" OP_DESC="Gamma $g"
}

gw_op_saturation() {
  gw_about "Saturation" "" \
    "How vivid the colors are." \
    "  -100 = fully gray · 0 = unchanged · 100 = twice as vivid"
  local p
  gw_ask p "Percent, -100 to 100" "30" || return 1
  OP_SUB=(effects saturation) OP_FLAGS=(-p "$p") OP_TAG="sat$p" OP_DESC="Saturation $p%"
}

gw_op_grayscale() {
  gw_about "Grayscale" "" "Removes all color: shades of gray only."
  OP_SUB=(effects grayscale) OP_TAG="gray" OP_DESC="Grayscale"
}

gw_op_flip() {
  gw_about "Flip" "" \
    "Swaps left and right, like looking at the picture in a mirror."
  OP_SUB=(effects flip) OP_TAG="flip" OP_DESC="Flip"
}

gw_op_mirror() {
  gw_about "Mirror" "" \
    "Keeps the left half and reflects it onto the right one: a symmetric picture."
  OP_SUB=(effects mirror) OP_TAG="mirror" OP_DESC="Mirror"
}

gw_op_tilt() {
  gw_about "3D tilt" "" \
    "Shrinks the picture, rounds its corners and tilts it in 3D over a gradient" \
    "(or another image) — the look of app screenshots on product pages." \
    "Presets p1-p4 are ready-made angle sets; Custom lets you set everything."
  local p s r x y z bg a b
  gw_choose p "Look" \
    "p1 — preset" "p2 — preset" "p3 — preset" "p4 — preset" \
    "custom — set size, angles and background yourself" || return 1
  OP_SUB=(effects tilt) OP_TAG="tilt"
  if [ "$p" != custom ]; then
    OP_FLAGS=(-p "$p") OP_TAG="tilt-$p" OP_DESC="3D tilt preset $p"
    return
  fi
  gw_ask s "Size of the picture inside the frame, 0.1 to 1" "0.65" || return 1
  gw_ask r "Corner radius, px" "40" || return 1
  gw_ask x "Tilt forward/back (X axis), degrees" "5" || return 1
  gw_ask y "Tilt left/right (Y axis), degrees" "-8" || return 1
  gw_ask z "Rotation (Z axis), degrees, positive = clockwise" "3" || return 1
  OP_FLAGS=(-s "$s" -r "$r" -x "$x" -y "$y" -z "$z")
  OP_DESC="3D tilt x$x° y$y° z$z°, size $s, radius $r"
  gw_choose bg "Background" \
    "gradient — from one color to another" \
    "image — another picture behind it" || return 1
  if [ "$bg" = image ]; then
    gw_pick_image b || return 1
    OP_FLAGS+=(-i "$b")
    OP_DESC+=", over $(basename "$b")"
  else
    gw_ask a "Gradient start color" "#121212" || return 1
    gw_ask b "Gradient end color" "#282828" || return 1
    OP_FLAGS+=(-b "$a" -e "$b")
    OP_DESC+=", gradient $a → $b"
  fi
}

gw_op_pixelate() {
  gw_about "Pixel art" "" \
    "Turns the picture into big square blocks." \
    "Scale 1-25: lower = bigger blocks. Big pictures need low values: for a" \
    "4K wallpaper try 3-8. Start high and go down until you like it."
  local s
  gw_ask s "Scale, 1 to 25" "15" || return 1
  OP_SUB=(pixelate) OP_FLAGS=(-s "$s") OP_TAG="pixel$s" OP_DESC="Pixel art, scale $s"
}

gw_op_border() {
  gw_about "Border" "" \
    "Draws a frame of one color around the edge, inside the picture (the size" \
    "stays the same). Radius > 0 rounds the frame's and the picture's corners."
  local c b r
  gw_ask c "Color (hex)" "#5D3FD3" || return 1
  gw_ask b "Thickness, px" "5" || return 1
  gw_ask r "Corner radius, px (0 = square)" "0" || return 1
  OP_SUB=(draw border) OP_FLAGS=(-c "$c" -b "$b" -r "$r") OP_TAG="border"
  OP_DESC="Border $c, ${b}px, radius $r"
}

gw_op_grid() {
  gw_about "Grid" "" \
    "Draws a grid of lines over the picture, like graph paper." \
    "Only on transparent pixels = the grid shows just where the background was" \
    "removed (run Remove background first)."
  local s t c m
  gw_ask s "Cell size, px" "80" || return 1
  gw_ask t "Line thickness, px" "1" || return 1
  gw_ask c "Color (hex)" "#5D3FD3" || return 1
  OP_SUB=(draw grid) OP_FLAGS=(-s "$s" -t "$t" -c "$c") OP_TAG="grid"
  OP_DESC="Grid ${s}px, ${t}px lines, $c"
  gw_choose m "Where" \
    "everywhere — over the whole picture" \
    "transparent — only on transparent pixels" || return 1
  [ "$m" = transparent ] && OP_FLAGS+=(-m) && OP_DESC+=", transparent only"
  return 0
}

gw_op_round() {
  gw_about "Round corners" "" \
    "Cuts the corners round; they become transparent (keep png/webp for that)."
  local r
  gw_ask r "Radius, px" "30" || return 1
  OP_SUB=(draw round) OP_FLAGS=(-r "$r") OP_TAG="round$r" OP_DESC="Round corners ${r}px"
}

gw_op_resize() {
  gw_about "Resize" "" \
    "Scales to exactly WIDTHxHEIGHT. A size with other proportions than the" \
    "original stretches the picture." \
    "lanczos — sharpest, best for making smaller · catmullrom — a bit softer." \
    "To make a small picture bigger AND sharp use AI upscale instead."
  local d m
  gw_ask d "Size, WIDTHxHEIGHT (now $(magick identify -format '%wx%h' "$1[0]"))" \
    "$(magick identify -format '%wx%h' "$1[0]")" || return 1
  gw_choose m "Method" \
    "lanczos — sharpest" \
    "catmullrom — slightly softer" || return 1
  OP_SUB=(resize) OP_FLAGS=(-d "$d" -m "$m") OP_TAG="$d" OP_DESC="Resize $d, $m"
}

gw_op_compress() {
  gw_about "Compress" "" \
    "Makes the file smaller. The method also sets the output format." \
    "Lossy = much smaller, tiny quality loss; lossless = a bit smaller, identical." \
    "Quality 0-100: lower = smaller and worse. 80 usually looks the same." \
    "Sizes before/after are shown under the menu."
  local m q s=4
  gw_choose m "Method" \
    "pngquant — png, lossy: fewer colors, much smaller" \
    "losslesspng — png, lossless" \
    "lossyjpg — jpg" \
    "lossywebp — webp, keeps transparency" \
    "lossyavif — avif, smallest" || return 1
  gw_ask q "Quality, 0 to 100" "80" || return 1
  [ "$m" = pngquant ] && { gw_ask s "Speed, 1 (slow, best) to 11 (fast, rough)" "4" || return 1; }
  OP_SUB=(compress) OP_FLAGS=(-m "$m" -q "$q" -s "$s") OP_TAG="q$q" OP_STDOUT=0
  OP_DESC="Compress $m, quality $q"
  case $m in
    *png*) OP_EXT=png ;;
    lossyjpg) OP_EXT=jpg ;;
    lossywebp) OP_EXT=webp ;;
    lossyavif) OP_EXT=avif ;;
  esac
}

gw_op_upscale() {
  gw_about "AI upscale" "" \
    "Makes the picture 2-4 times bigger with a neural network (Real-ESRGAN):" \
    "edges and details are redrawn sharp instead of blurry. Needs a GPU with" \
    "Vulkan; the first run offers to download the upscaler. A black result means" \
    "the GPU can't run it."
  local m s=4
  gw_choose m "Model" \
    "realesr-animevideov3 — fast, drawn / anime style" \
    "realesrgan-x4plus-anime — anime, better details" \
    "realesrgan-x4plus — photos and everything else, slow, always x4" || return 1
  [ "$m" != realesrgan-x4plus ] && { gw_choose s "How many times bigger" 2 3 4 || return 1; }
  OP_SUB=(upscale) OP_FLAGS=(-m "$m" -s "$s") OP_TAG="x$s" OP_STDOUT=0
  OP_DESC="Upscale ×$s, $m"
}

gw_op_bg() {
  gw_about "Remove background" "" \
    "Cuts out the main object; the background becomes transparent or a color." \
    "u2net — AI, good default · bria-rmbg — AI, best edges, heavier and slower" \
    "kmeans — no AI, groups similar colors; for flat simple backgrounds." \
    "The AI models run on the CPU; the first run offers to download them" \
    "(to ~/.u2net)."
  local m c i v s r
  gw_choose m "Method" \
    "u2net — AI, default" \
    "bria-rmbg — AI, best quality, slower" \
    "kmeans — no AI, simple backgrounds" || return 1
  gw_ask c "New background: transparent or a color (hex)" "transparent" || return 1
  OP_SUB=(bg) OP_FLAGS=(-m "$m" --bg-color "$c") OP_TAG="nobg" OP_STDOUT=0 OP_EXT=png
  OP_DESC="Remove background, $m → $c"
  [ "$m" = kmeans ] || return 0
  gw_yes "Tune kmeans (iterations, convergence, sample rate, threads)?" || return 0
  gw_ask i "Max iterations (more = finer split, slower)" "100" || return 1
  gw_ask v "Convergence threshold (lower = more precise, slower)" "0.001" || return 1
  gw_ask s "Sample rate, 0-1 (share of pixels used to learn the colors)" "0.5" || return 1
  gw_ask r "Threads" "4" || return 1
  OP_FLAGS+=(-i "$i" -c "$v" -s "$s" -r "$r")
}

# Label shown in the menus | op function.
GW_OPS=(
  "Recolor to a theme — catppuccin, nord, gruvbox… or your own|gw_op_theme"
  "Replace a color — one exact color for another|gw_op_replace"
  "Invert colors — white ↔ black, every color to its opposite|gw_op_invert"
  "Change format — png / jpg / webp / avif|gw_op_format"
  "Brightness — lighter or darker overall|gw_op_brightness"
  "Contrast — more or less difference between light and dark|gw_op_contrast"
  "Gamma — lighter or darker mid-tones, blacks and whites stay|gw_op_gamma"
  "Saturation — more vivid or more washed-out colors|gw_op_saturation"
  "Grayscale — black and white|gw_op_grayscale"
  "Flip — swap left and right|gw_op_flip"
  "Mirror — left half reflected onto the right|gw_op_mirror"
  "3D tilt — tilted card with round corners on a gradient|gw_op_tilt"
  "Pixel art — big square blocks|gw_op_pixelate"
  "Border — a colored frame around the edge|gw_op_border"
  "Grid — lines like graph paper|gw_op_grid"
  "Round corners — transparent rounded corners|gw_op_round"
  "Resize — exact width × height|gw_op_resize"
  "Compress — smaller file|gw_op_compress"
  "AI upscale — 2-4× bigger and sharp (GPU)|gw_op_upscale"
  "Remove background — cut out the main object|gw_op_bg"
)

# gw_pick_op — runs the chosen gw_op_* on $1 and remembers it in GW_OP_FN
# (for Retry); returns 1 when cancelled.
gw_pick_op() {
  local labels=() e choice
  for e in "${GW_OPS[@]}"; do labels+=("${e%%|*}"); done
  choice=$(gum choose --height 25 --header "What to do" "${labels[@]}" </dev/tty) || return 1
  for e in "${GW_OPS[@]}"; do
    if [ "${e%%|*}" = "$choice" ]; then
      GW_OP_FN=${e#*|}
      gw_op_reset
      "$GW_OP_FN" "$1"
      return
    fi
  done
}

# gw_apply <in> <out without extension> — run the picked op; prints the result.
gw_apply() {
  local in=$1 out=$2
  if [ "$OP_STDOUT" = 1 ]; then
    out+=".${in##*.}"
    gum spin --title "gowall ${OP_SUB[*]}..." -- \
      bash -c 'gowall "$@" > "$0"' "$out" "${OP_SUB[@]}" "$in" - "${OP_FLAGS[@]}" --preview false || return 2
  else
    out+=".${OP_EXT:-${in##*.}}"
    # No spinner: upscale and bg may ask to download things first.
    gowall "${OP_SUB[@]}" "$in" "${OP_FLAGS[@]}" --output "$out" --preview false >&2 || return 2
  fi
  [ -s "$out" ] || return 2
  gw_fix_ext "$out"
}

# ─── Menu actions ─────────────────────────────────────────────────────────────

# The versions of one edit session. Version 0 is the original; every attempt
# adds one whose parent is the version it was made from. Dropped attempts stay,
# so History can show them and continue from them.
gw_version_add() {
  GW_V_FILE+=("$1") GW_V_PARENT+=("$2") GW_V_DESC+=("$3") GW_V_TAG+=("$4") GW_V_DROPPED+=("$5")
}

# gw_chain <version> — GW_CHAIN = the versions from the original to it.
gw_chain() {
  local i=$1
  GW_CHAIN=()
  while [ "$i" -ge 0 ]; do
    GW_CHAIN=("$i" "${GW_CHAIN[@]}")
    i=${GW_V_PARENT[$i]}
  done
}

# gw_chain_join <version> <GW_V_* array> <separator> — that field along the
# chain, without the original.
gw_chain_join() {
  local -n __field=$2
  local out="" i
  gw_chain "$1"
  for i in "${GW_CHAIN[@]:1}"; do out+="${out:+$3}${__field[$i]}"; done
  printf '%s' "$out"
}

gw_version_name() {
  local tags
  tags=$(gw_chain_join "$1" GW_V_TAG -)
  printf '%s' "$GW_BASE${tags:+-$tags}"
}

# fzf over every version of the session: how it was made, and the image.
gw_history() {
  local d="$GW_TMP/history" i mark line pick act preview chain lines
  while true; do
    rm -rf "$d"
    mkdir -p "$d"
    gw_chain "$GW_CUR"
    chain=" ${GW_CHAIN[*]} "
    lines=()
    for i in "${!GW_V_FILE[@]}"; do
      if [ "$i" -eq "$GW_CUR" ]; then mark="●"
      elif [[ $chain == *" $i "* ]]; then mark="✓"
      elif [ "${GW_V_DROPPED[$i]}" = 1 ]; then mark="✗"
      else mark="↩"
      fi
      line=$(printf '%-3s %s  %s' "$i" "$mark" "${GW_V_DESC[$i]}")
      [ "$i" -gt 0 ] && [ "${GW_V_PARENT[$i]}" -ne $((i - 1)) ] && line+="  (from ${GW_V_PARENT[$i]})"
      lines+=("$i"$'\t'"$line")
      {
        echo "${GW_V_DESC[$i]}  $mark"
        if [ "$i" -eq 0 ]; then echo "original"; else echo "original → $(gw_chain_join "$i" GW_V_DESC " → ")"; fi
        gw_info "${GW_V_FILE[$i]}"
        echo
      } >"$d/$i.txt"
      printf '%s' "${GW_V_FILE[$i]}" >"$d/$i.path"
    done
    preview="cat $d/{1}.txt"
    [ -n "$KITTY_WINDOW_ID" ] && preview+="; kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
      --place=\"\${FZF_PREVIEW_COLUMNS}x\$((FZF_PREVIEW_LINES - 4))@0x0\" \"\$(cat $d/{1}.path)\""
    pick=$(printf '%s\n' "${lines[@]}" | fzf --with-shell 'bash -c' --delimiter '\t' --with-nth 2 \
      --layout reverse --height 90% --no-sort --info inline \
      --header $'● current · ✓ in its chain · ↩ undone · ✗ dropped\nEnter: open, continue from it or save it' \
      --preview "$preview" --preview-window right,60% \
      --bind "load:pos($((GW_CUR + 1)))") || return 0
    i=${pick%%$'\t'*}
    gw_choose act "Version $i: ${GW_V_DESC[$i]}" \
      "Open — look at it in swayimg" \
      "Continue from here — make it the current version" \
      "Save — save this version, stay where you are" \
      "Back — to the list" || continue
    case $act in
      Open) gw_show "${GW_V_FILE[$i]}" ;;
      "Continue from here")
        GW_V_DROPPED[$i]=0
        GW_CUR=$i
        return 0
        ;;
      Save) gw_save "${GW_V_FILE[$i]}" "$(gw_version_name "$i")" >/dev/null ;;
    esac
  done
}

# Edit one image: any number of steps, each previewed and kept or dropped.
gw_edit() {
  local src=$1
  [ -n "$src" ] || gw_pick_image src || return 1
  gw_tmpdir
  GW_V_FILE=() GW_V_PARENT=() GW_V_DESC=() GW_V_TAG=() GW_V_DROPPED=()
  gw_version_add "$src" -1 "original" "" 0
  GW_CUR=0
  GW_BASE=$(basename "${src%.*}")
  local act cur res keep new chain
  while true; do
    cur=${GW_V_FILE[$GW_CUR]}
    chain=$(gw_chain_join "$GW_CUR" GW_V_DESC " → ")
    local opts=("Add a change — pick from all edits")
    [ "$GW_CUR" -gt 0 ] && opts+=(
      "Undo — back to the previous version (drops: ${GW_V_DESC[$GW_CUR]})"
      "Finish — save, set as wallpaper or copy")
    [ ${#GW_V_FILE[@]} -gt 1 ] && opts+=("History — every version of this session, with previews")
    opts+=("Preview — look at the current version" "Quit — throw everything away")
    gw_choose act "$(basename "$src") · ${chain:-no changes yet} · $(gw_info "$cur")" "${opts[@]}" || act=Quit
    case $act in
      "Add a change")
        gw_pick_op "$cur" || continue
        while true; do
          new=${#GW_V_FILE[@]}
          res=$(gw_apply "$cur" "$GW_TMP/v$new") || { print_error_message "gowall failed"; break; }
          gw_version_add "$res" "$GW_CUR" "${OP_DESC:-${OP_SUB[*]} ${OP_FLAGS[*]}}" "$OP_TAG" 1
          echo ":: ${GW_V_DESC[$new]}: $(gw_info "$cur") → $(gw_info "$res")"
          gw_show "$res"
          gw_choose keep "Keep this change?" \
            "Keep — continue editing from here" \
            "Retry — same edit, other settings" \
            "Drop — back to the previous version" || keep=Drop
          case $keep in
            Keep)
              GW_V_DROPPED[$new]=0
              GW_CUR=$new
              break
              ;;
            Retry) gw_op_reset; "$GW_OP_FN" "$cur" || break ;;
            Drop) break ;;
          esac
        done
        ;;
      Undo) GW_CUR=${GW_V_PARENT[$GW_CUR]} ;;
      History) gw_history ;;
      Finish)
        gw_finish "$cur" "$(gw_version_name "$GW_CUR")"
        return 0
        ;;
      Preview) gw_show "$cur" ;;
      Quit)
        [ ${#GW_V_FILE[@]} -eq 1 ] || gw_yes "Throw away all $((${#GW_V_FILE[@]} - 1)) version(s)?" || continue
        return 1
        ;;
    esac
  done
}

gw_batch() {
  gw_about "Same change on many images" "" \
    "Pick the images and one edit. It is previewed on the first image; if it" \
    "looks right, gowall applies it to all of them and saves into one folder."
  local files act res out
  gw_pick_images files || return 1
  gw_tmpdir
  while true; do
    gw_pick_op "${files[0]}" || return 1
    res=$(gw_apply "${files[0]}" "$GW_TMP/batch-preview") || { print_error_message "gowall failed"; return 2; }
    gw_show "$res"
    gw_choose act "Apply to all ${#files[@]} images?" \
      "Apply — run on every image" \
      "Retry — pick the edit again" \
      "Cancel" || return 1
    [ "$act" = Apply ] && break
    [ "$act" = Cancel ] && return 1
  done
  gw_ask out "Save into folder" "$GW_OUT_DIR/$OP_TAG" || return 1
  out=$(gw_expand "$out")
  mkdir -p "$out"
  gowall "${OP_SUB[@]}" --batch "$(gw_batch_arg "${files[@]}")" "${OP_FLAGS[@]}" \
    --output "$out" --preview false --yes
  check_success "${#files[@]} images → $out"
}

gw_stack() {
  gw_about "Stack images" "" \
    "Puts several images into one: side by side, one under another, or a grid." \
    "Grid NxM: N images per row, M rows; empty cells stay transparent." \
    "Border = gap in px between and around the images, filled with the color."
  local files l b c r res act
  gw_pick_images files || return 1
  gw_tmpdir
  while true; do
    gw_ask l "Layout: vertical, horizontal or a grid like 2x2 (${#files[@]} images)" "horizontal" || return 1
    gw_ask b "Gap / border, px" "0" || return 1
    gw_ask c "Gap color (hex)" "#000000" || return 1
    gw_choose r "Different sizes" \
      "off — keep every image as it is" \
      "biggest — shrink all to the smallest one's size" || return 1
    res="$GW_TMP/stack.png"
    gowall stack --batch "$(gw_batch_arg "${files[@]}")" -l "$l" -b "$b" -c "$c" -r "$r" \
      --output "$res" --preview false >&2 && [ -s "$res" ] || { print_error_message "gowall failed"; return 2; }
    gw_show "$res"
    gw_choose act "Like it?" "Keep — save or set as wallpaper" "Retry — other settings" || return 1
    [ "$act" = Keep ] && break
  done
  gw_finish "$res" "stack-$l"
}

gw_gif() {
  gw_about "Make a GIF" "" \
    "Every image becomes one frame, in the order you marked them (or by name" \
    "for a whole folder). Delay is in hundredths of a second: 100 = 1 s." \
    "Loops: 0 = forever, -1 = play once, n = play n+1 times."
  local files d l r res act
  gw_pick_images files || return 1
  gw_tmpdir
  while true; do
    gw_ask d "Delay between frames, 1/100 s" "100" || return 1
    gw_ask l "Loops (0 = forever)" "0" || return 1
    gw_choose r "Different sizes" \
      "1 — resize all frames to one size (safe)" \
      "0 — they are already the same size (faster)" || return 1
    res="$GW_TMP/anim.gif"
    gowall gif --batch "$(gw_batch_arg "${files[@]}")" -d "$d" -l "$l" -r "$r" \
      --output "$res" --preview false >&2 && [ -s "$res" ] || { print_error_message "gowall failed"; return 2; }
    gw_show "$res"
    gw_choose act "Like it?" "Keep — save it" "Retry — other settings" || return 1
    [ "$act" = Keep ] && break
  done
  gw_finish "$res" "anim"
}

gw_ocr() {
  gw_about "Text from an image or PDF (OCR)" "" \
    "Sends the file to an OCR provider and returns the text as markdown or plain" \
    "text. Local: tesseract, docling, ollama, vllm, oc (any OpenAI-compatible" \
    "server). Cloud: openai, openrouter, gemini, mistral — their API keys go in" \
    "~/.gowall/.env (OPENROUTER_API_KEY=..., GEMINI_API_KEY=...)." \
    "Schemas = saved provider settings in ~/.config/gowall/schema.yml." \
    "Tip: take a niri screenshot (it lands in the clipboard), then pick Clipboard."
  local f how s p m fmt l d txt act schemas=()
  gw_pick_file f "image or PDF" png jpg jpeg webp avif pdf || return 1
  local args=()
  [ -f "$CONFIG_DIR/gowall/schema.yml" ] &&
    mapfile -t schemas < <(sed -n 's/^ *- *name: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$CONFIG_DIR/gowall/schema.yml")
  if [ ${#schemas[@]} -gt 0 ]; then
    gw_choose how "Settings" "schema — one saved in schema.yml" "manual — pick provider and model now" || return 1
  else
    how=manual
  fi
  if [ "$how" = schema ]; then
    gw_choose s "Schema" "${schemas[@]}" || return 1
    args+=(-s "$s")
  else
    gw_choose p "Provider" \
      "tesseract — local, classic OCR, no model needed" \
      "docling — local, documents and tables" \
      "ollama — local LLM (e.g. qwen2.5vl:7b)" \
      "vllm — local LLM server" \
      "oc — any OpenAI-compatible server" \
      "openai — cloud" \
      "openrouter — cloud, has free models" \
      "gemini — cloud" \
      "mistral — cloud" || return 1
    gw_ask m "Model (empty for tesseract)" "" || return 1
    args+=(-p "$p")
    [ -n "$m" ] && args+=(-m "$m")
  fi
  gw_choose fmt "Output" "md — markdown, keeps headings and tables" "txt — plain text" || return 1
  gw_ask l "Language (empty = provider default; tesseract: eng, rus · docling: en, ru)" "" || return 1
  args+=(-f "$fmt")
  [ -n "$l" ] && args+=(-l "$l")
  if [ "${f##*.}" = pdf ]; then
    gw_ask d "PDF → image DPI (higher = sharper, slower)" "120" || return 1
    args+=(-d "$d")
  fi
  gw_tmpdir
  txt="$GW_TMP/ocr.$fmt"
  gum spin --title "OCR..." -- bash -c 'gowall ocr "$@" > "$0"' "$txt" "$f" - "${args[@]}" &&
    [ -s "$txt" ] || { print_error_message "OCR failed"; return 2; }
  gum pager <"$txt" </dev/tty
  while true; do
    gw_choose act "Text: $(wc -w <"$txt") words" \
      "Copy — to the clipboard" \
      "Save — as a file" \
      "Read again" \
      "Done" || return 0
    case $act in
      Copy) wl-copy <"$txt" && print_success_message "Copied" ;;
      Save) gw_save "$txt" "ocr/$(basename "${f%.*}")" >/dev/null ;;
      "Read again") gum pager <"$txt" </dev/tty ;;
      Done) return 0 ;;
    esac
  done
}

# Hex codes on stdin → a color block in front of each.
gw_swatches() {
  local h r g b
  while read -r h; do
    [[ $h =~ ^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$ ]] || { echo "$h"; continue; }
    r=$((16#${BASH_REMATCH[1]})) g=$((16#${BASH_REMATCH[2]})) b=$((16#${BASH_REMATCH[3]}))
    printf '\e[48;2;%d;%d;%dm        \e[0m %s\n' "$r" "$g" "$b" "$h"
  done
}

gw_palette() {
  gw_about "Color palette of an image" "" \
    "The main colors of the picture as hex codes, like pywal does (6-16 is a" \
    "good amount). A one-color picture returns that color plus its shades."
  local f c pal act
  gw_pick_image f || return 1
  gw_ask c "How many colors" "8" || return 1
  pal=$(gowall extract "$f" -c "$c") || return 2
  gw_swatches <<<"$pal"
  gw_choose act "Next" \
    "Copy — all hex codes to the clipboard" \
    "Open in browser — gowall's hex preview site" \
    "Done" || return 0
  case $act in
    Copy) wl-copy <<<"$pal" && print_success_message "Copied" ;;
    "Open in browser") gowall extract "$f" -c "$c" -p >/dev/null ;;
  esac
}

gw_themes() {
  gw_about "Themes" "" \
    "All themes gowall can recolor to, built-in and your own from" \
    "~/.config/gowall/config.yml. Pick one to see its colors."
  local t act
  gw_pick_theme t || return 1
  gowall list -t "$t" | gw_swatches
  gw_choose act "Next" \
    "Copy — the theme's hex codes" \
    "Open in browser — gowall's hex preview site" \
    "Done" || return 0
  case $act in
    Copy) gowall list -t "$t" | wl-copy && print_success_message "Copied" ;;
    "Open in browser") gowall list -t "$t" -p >/dev/null ;;
  esac
}

gw_colors() {
  local tool c c2 n f t d r m res
  gw_choose tool "Color tool" \
    "blend — colors in between two colors" \
    "convert — one color in hex / rgb / hsl / lab" \
    "light — a lighter version of a color" \
    "dark — a darker version of a color" \
    "variants — shades, tints or tones of a color" \
    "wheel — matching colors from the color wheel" \
    "gradient — a gradient image (e.g. a wallpaper)" || return 1
  case $tool in
    blend)
      gw_about "Blend" "" "Steps between two colors, e.g. for a smooth palette."
      gw_ask c "First color" "#" && gw_ask c2 "Second color" "#" &&
        gw_ask n "How many colors in between" "3" || return 1
      gowall color blend "$c" "$c2" -n "$n"
      ;;
    convert)
      gw_about "Convert" "" "Write a color in another notation: hex #ff8800, rgb(255,136,0)," \
        "hsl(32,100,50), lab — the input can be any of them."
      gw_ask c "Color" "#" || return 1
      gw_choose t "Convert to" hex rgb hsl lab || return 1
      gowall color convert "$c" -t "$t"
      ;;
    light | dark)
      gw_about "$tool" "" "Factor 0-1: 0.3 = 30% ${tool}er."
      gw_ask c "Color" "#" && gw_ask f "Factor, 0 to 1" "0.3" || return 1
      gowall color "$tool" "$c" -f "$f"
      ;;
    variants)
      gw_about "Variants" "" \
        "shades — the color mixed with black (darker)" \
        "tints — mixed with white (lighter)" \
        "tones — mixed with gray (calmer, less vivid)"
      gw_ask c "Color" "#" || return 1
      gw_choose t "Type" "shades — darker" "tints — lighter" "tones — grayer" || return 1
      gw_ask n "How many" "5" || return 1
      gowall color variants "$c" -t "$t" -n "$n"
      ;;
    wheel)
      gw_about "Color wheel" "" \
        "Colors that go well with the given one:" \
        "complementary — the opposite one · contrast — a strongly contrasting one" \
        "analogous — its neighbours · triadic — 3 evenly spaced" \
        "quadratic — 4 evenly spaced · split-complementary — the two next to the opposite"
      gw_ask c "Color" "#" || return 1
      gw_choose t "Scheme" complementary contrast analogous triadic quadratic split-complementary || return 1
      gowall color wheel "$c" -t "$t"
      ;;
    gradient)
      gw_about "Gradient image" "" \
        "A picture fading through 2+ colors — e.g. a plain wallpaper." \
        "Direction: horizontal, vertical, or an angle 0-360." \
        "Method = how colors are mixed: rgb — straight, the middle can look muddy;" \
        "lab / hcl / luv / luvlch — even, natural-looking; hsv — goes around the" \
        "hue wheel, rainbow-like."
      gw_ask c "Colors, comma-separated" "#1e1e2e,#cba6f7" || return 1
      d=$(niri msg -j focused-output 2>/dev/null | jq -r '.modes[.current_mode] | "\(.width)x\(.height)"' 2>/dev/null)
      gw_ask d "Size, WIDTHxHEIGHT (default: this screen)" "${d:-1920x1080}" || return 1
      gw_ask r "Direction" "horizontal" || return 1
      gw_choose m "Method" "lab — even" "hcl — even, keeps colors vivid" "rgb — straight" "hsv — rainbow-like" "luv — even" "luvlch — even" || return 1
      gw_tmpdir
      res="$GW_TMP/gradient.png"
      gowall color gradient "$c" - -d "$d" -r "$r" -m "$m" --preview false >"$res" && [ -s "$res" ] || return 2
      gw_show "$res"
      gw_finish "$res" "gradient"
      return
      ;;
  esac
  read -rsn1 -p ":: Press any key" </dev/tty
  echo
}

gw_icon() {
  gw_about "Recolor an icon (SVG / ICO)" "" \
    "gowall only reads raster images, so the icon is rendered to PNG, recolored" \
    "to a theme and turned back:" \
    "  png — just the recolored PNG" \
    "  svg — an SVG with the PNG inside: opens anywhere as SVG but doesn't scale" \
    "  traced svg — real vector via inkscape (colors traced, needs inkscape)" \
    "  ico — back to an .ico with the usual sizes (16-256)"
  local f t size out res fmt opts
  gw_pick_file f icon svg ico || return 1
  gw_pick_theme t || return 1
  gw_tmpdir
  res="$GW_TMP/icon.png"
  if [ "${f##*.}" = svg ]; then
    gw_ask size "Render size, px" "256" || return 1
    rsvg-convert -b none -f png -w "$size" -h "$size" "$f" | gowall convert - - -t "$t" --preview false >"$res"
  else
    local big
    big=$(magick identify -format '%p %w\n' "$f" | sort -k2 -n | tail -1 | cut -d' ' -f1)
    magick "$f[$big]" png:- | gowall convert - - -t "$t" --preview false >"$res"
  fi
  [ -s "$res" ] || { print_error_message "gowall failed"; return 2; }
  gw_show "$res"
  opts=("png — recolored PNG" "svg — SVG wrapper around the PNG")
  command -v inkscape &>/dev/null && opts+=("traced svg — real vector via inkscape")
  opts+=("ico — Windows icon, 16-256 px")
  gw_choose fmt "Save as" "${opts[@]}" || return 1
  out="$GW_TMP/icon-out"
  case $fmt in
    png) out=$res ;;
    svg)
      out+=.svg
      local w h
      read -r w h < <(magick identify -format '%w %h' "$res")
      printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s"><image href="data:image/png;base64,%s" width="%s" height="%s"/></svg>\n' \
        "$w" "$h" "$(base64 -w0 "$res")" "$w" "$h" >"$out"
      ;;
    "traced svg")
      out+=.svg
      inkscape --pipe --trace-bitmap --colors 10 --export-plain-svg="$out" <"$res" || return 2
      ;;
    ico)
      out+=.ico
      magick "$res" -define icon:auto-resize=256,128,64,48,32,16 "$out" || return 2
      ;;
  esac
  gw_save "$out" "icons/$(basename "${f%.*}")-$(basename "$t" .json)" >/dev/null
}

# gowall 0.2.4's -w reads Reddit's JSON API, which answers 403. Its master
# reads the RSS feed instead (no release yet); this does the same: the image of
# the top post of the day.
gw_daily() {
  gw_about "Wallpaper of the day" "" \
    "The top post of the day on r/wallpaper (what gowall -w shows): new every" \
    "day. Previewed first; then save it, set it as wallpaper or edit it."
  local feed entry title url f act
  # Reddit answers 429 to quick repeats; a minute later it works again.
  feed=$(curl -fsS -A 'Mozilla/5.0 (compatible; gowall/1.0)' 'https://www.reddit.com/r/wallpaper/top/.rss?t=day') ||
    { print_error_message "Reddit refused, try in a minute"; return 2; }
  entry=$(sed 's/<entry>/\n<entry>/g' <<<"$feed" | sed -n 2p)
  title=$(sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' <<<"$entry" | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&#39;/'"'"'/g')
  url=$(grep -oE 'https://(i|preview)\.redd\.it/[^"&<?]+' <<<"$entry" | head -1)
  url=${url/preview.redd.it/i.redd.it}
  [ -n "$url" ] || { print_error_message "No image in today's top post"; return 2; }
  gw_tmpdir
  f="$GW_TMP/daily.${url##*.}"
  curl -fsSL -o "$f" "$url" || { print_error_message "Download failed"; return 2; }
  echo ":: $title — $(gw_info "$f")"
  gw_show "$f"
  gw_choose act "$title" \
    "Keep — save it or set it as wallpaper" \
    "Edit — recolor or change it first" \
    "Skip" || return 1
  case $act in
    Keep) gw_finish "$f" "daily-$(date +%F)" ;;
    Edit) gw_edit "$f" ;;
    Skip) return 1 ;;
  esac
}

gowall_commands() {
  menu "⬅️ Back" \
    "Edit an image — recolor, effects, draw, resize, AI; preview after each step|gw_edit" \
    "Same change on many images — preview on the first, then all at once|gw_batch" \
    "Stack images — side by side, one under another or a grid|gw_stack" \
    "Make a GIF — images become animation frames|gw_gif" \
    "Text from an image or PDF — OCR|gw_ocr" \
    "Palette of an image — its main colors as hex|gw_palette" \
    "Themes — list them and see their colors|gw_themes" \
    "Color tools — blend, lighten, shades, color wheel, gradient image|gw_colors" \
    "Recolor an icon — SVG or ICO to a theme|gw_icon|rsvg-convert+magick" \
    "Wallpaper of the day — community-voted, new every day|gw_daily"
}

# gw [image] — straight to editing that image, or the menu.
gw() {
  require_gum gw || return 1
  if [ -n "$1" ]; then
    [ -f "$1" ] || { print_error_message "No such file: $1"; return 1; }
    gw_edit "$(realpath "$1")"
  else
    gowall_commands
  fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && "$@"
