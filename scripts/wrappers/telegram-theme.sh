#!/bin/bash
#
# matugen post_hook (matugen/config.toml): packs the rendered Telegram colors
# (matugen/templates/telegram-colors.tdesktop-theme) and a chat background into
# a .tdesktop-theme — a zip of colors.tdesktop-theme + background.png. A palette
# alone can't carry the background, so the chat kept Telegram's own.
#
#   telegram-theme.sh <colors.tdesktop-theme> <out.tdesktop-theme>
#
# Telegram, iMe and AyuGram watch the theme file they applied and load it again
# when it changes; the new file replaces the old one in a single rename, so
# they never read half a zip.

colors=$1 out=$2
[ -s "$colors" ] || exit 0
mkdir -p "$(dirname "$out")"
dir=$(mktemp -d "$(dirname "$out")/.telegram-theme.XXXXXX") || exit 1
trap 'rm -rf "$dir"' EXIT

cp "$colors" "$dir/colors.tdesktop-theme"
files=(colors.tdesktop-theme)
read -r top bottom < <(sed -n 's#^// chat-background: ##p' "$colors")
if command -v magick &>/dev/null && [ -n "$bottom" ]; then
  magick -size 1080x1920 "gradient:$top-$bottom" -depth 8 "$dir/background.png" &&
    files+=(background.png)
fi

(cd "$dir" && python3 -I -m zipfile -c theme.zip "${files[@]}") &&
  mv -f "$dir/theme.zip" "$out"
