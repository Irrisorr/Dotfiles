#!/bin/sh
#
# Re-applies spicetify after Spotify was installed or updated, which puts its
# stock files back. Run as root by the package manager's hook (pacman:
# etc/pacman.d/hooks/spicetify.hook, apt: etc/apt/apt.conf.d/99spicetify),
# installed as /usr/local/bin/spicetify-reapply by the installer's Spicetify step.
#
# Stock Spotify has Apps/xpui.spa (spicetify unpacks it), so nothing happens
# for any other package. spicetify refuses root: it runs as every user with a
# spicetify config, after the update made Spotify's files root-only again.

for spotify in /opt/spotify /usr/share/spotify; do
  [ -f "$spotify/Apps/xpui.spa" ] && break
done
[ -f "$spotify/Apps/xpui.spa" ] || exit 0
command -v spicetify >/dev/null || exit 0

chmod a+wr "$spotify" && chmod -R a+wr "$spotify/Apps"

for d in /home/*/.config/spicetify; do
  [ -e "$d" ] || continue
  u=$(stat -L -c %U "$d")
  h=$(getent passwd "$u" | cut -d: -f6)
  as_user() { runuser -u "$u" -- env HOME="$h" "$@"; }
  as_user spicetify backup apply -n -q || echo "spicetify: run 'spicetify backup apply' as $u"
  # The new [Backup] version changes the file's size, which git takes for a
  # change even when its filter blanks that line; restaging updates its stat.
  as_user git -C "$d" diff --quiet -- config-xpui.ini 2>/dev/null &&
    as_user git -C "$d" add -- config-xpui.ini 2>/dev/null
done
exit 0
