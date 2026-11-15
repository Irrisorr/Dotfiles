# Spotify (spicetify)

Spotify painted in the wallpaper colors, plus Marketplace, Listening Stats and
Spicy Lyrics with their settings kept here. Everything is driven by the `spice`
menu and the installer's Spicetify step.

## How it fits together

```
wallpaper change ─► DMS runs matugen ─► Themes/dms-colors/color.ini
                                            │ post_hook: spicetify refresh -s
                                            ▼
                         /opt/spotify/Apps/xpui/colors.css, user.css
                                            │ dms-live.js re-reads them every 2 s
                                            ▼
                                  open Spotify repaints, no restart
```

- `~/.config/spicetify` is a symlink to this folder, as a whole. Whatever
  spicetify, the installers or `spice` write lands here, so a plugin update
  never breaks the link; it only shows up as a change in `git status`.
- `~/.config/matugen` is a symlink to `Dotfiles/matugen`: our own matugen
  template, which DMS runs after its own (`runUserMatugenTemplates`).
- spicetify patches Spotify's files in `/opt/spotify`. A Spotify update undoes
  the patch; the pacman hook puts it back (`spicetify backup apply`).

## Files

| File | What it is |
|---|---|
| `config-xpui.ini` | spicetify's config: theme (`current_theme`, `color_scheme`), `extensions`, `custom_apps`. `spice` writes it; commit its changes |
| `Themes/dms-colors/user.css` | The wallpaper theme: paints Spotify's own color tokens (`--background-base`, `--text-subdued`, the green accent, …) with the matugen colors, mixes 10-20 % of the accent into the near-black DMS surfaces, accent on the play button and progress bars |
| `Themes/dms-colors/color.ini` | The colors themselves, written by DMS on every wallpaper change. Not in git |
| `Themes/marketplace/color.ini` | Placeholder theme Marketplace needs while one of its themes is picked |
| `Extensions/dms-live.js` | Repaints an open Spotify when `colors.css` / `user.css` change (swaps the stylesheet, nothing flashes) |
| `Extensions/lyrics-settings.js` | Spicy Lyrics' saved settings (`SAVED`, written by `spice lyrics`); gives them to a Spotify that hasn't had them and adds "Restore saved Spicy Lyrics settings" to the profile menu |
| `CustomApps/marketplace/`, `CustomApps/listening-stats/` | Downloaded by their official installers. Not in git: the installer step and `spice` → Update apps put them back |
| `marketplace-backup.json` | Marketplace's own backup (installed themes, extensions, snippets), once saved with `spice` → Marketplace backup |

Elsewhere in the dotfiles:

| File | What it is |
|---|---|
| `scripts/functions/spicetify.sh` | The `spice` menu |
| `fish/functions/spice.fish` | `spice` in fish; passes its arguments on (`spice lyrics`) |
| `scripts/functions/alias_menu.sh` | "Spotify (spicetify)" in the `asd` menu runs `spice` |
| `scripts/lib/spotify_storage.py` | Reads one localStorage value of Spotify from disk (LevelDB, no module needed; works while Spotify runs) |
| `scripts/install/apps/spicetify.sh` | The installer's Spicetify step (`configure_spicetify`) |
| `matugen/config.toml`, `matugen/templates/spicetify-color.ini` | The matugen template that writes `color.ini` |
| `etc/pacman.d/hooks/spicetify.hook` | Re-applies spicetify after every Spotify install / update, as the owner of each `~/.config/spicetify` |

## `spice`

`spice` in a terminal (or "Spotify (spicetify)" in `asd`) opens the menu; the
line above it shows the theme, the custom apps and the extensions that are on.

| Item | What it does |
|---|---|
| Theme | Picks `dms-colors` (wallpaper colors, follows every change) or `marketplace` (the theme installed in Marketplace → Themes). Both stay in `Themes/`; the choice is kept in `config-xpui.ini`, then applies |
| Update apps | Marketplace and Listening Stats: installed version → latest release; outdated or missing ones are preselected. Runs each repo's official installer, which downloads into `CustomApps/` and applies. The picked theme stays |
| Marketplace backup | Save: after Marketplace → Settings → Back up (copies a JSON), stores the clipboard in `marketplace-backup.json`. Restore: copies it back for Marketplace → Settings → Restore |
| Lyrics settings | Same as `spice lyrics`, below |
| Extensions | Turns the files in `Extensions/` on / off, then applies. Marketplace's extensions are managed in Marketplace |
| Apply again | `spicetify apply`, after editing the config by hand |
| Repair after a Spotify update | `spicetify backup apply` — what the pacman hook does |
| Restore stock Spotify | `spicetify restore` (asks first); Repair puts spicetify back |
| DevTools | `spicetify enable-devtools` |

`spice lyrics` saves Spicy Lyrics' current settings into the dotfiles: reads
`SL:settings` from Spotify's storage, prints what changed against the saved
ones (`lyricsSize: 90 → 100`) and writes them into `lyrics-settings.js`. Turns
the extension on first if it's off. Spotify can stay open.

## What updates itself, and where settings live

- **Marketplace themes and extensions** load from their GitHub repos (via
  jsdelivr) on every Spotify start, so they update by themselves (jsdelivr may
  lag up to ~12 h). Marketplace stores only which ones are installed.
- **Marketplace and Listening Stats themselves** are files in `CustomApps/`:
  `spice` → Update apps.
- **Extension and app settings** are not files: each one keeps them in
  Spotify's localStorage (`~/.cache/spotify/Browser/Local Storage/leveldb`).
  A page in Spotify can't write files, so they get to the dotfiles only this
  way:
  - Marketplace's list of installed themes / extensions / snippets → Marketplace backup;
  - Spicy Lyrics → `spice lyrics`;
  - Listening Stats' history → export / import in its own Settings (JSON / CSV).

## New machine

1. Packages (`scripts/install/packages.txt`): `spotify`, `spicetify-cli` and its
   dependencies `unzip`, `python`, `wl-clipboard`; `jq`, `curl` and `gum` are used too.
2. Installer → Spicetify step:
   - links `~/.config/spicetify` and `~/.config/matugen`;
   - makes `/opt/spotify` writable for spicetify (sudo);
   - installs the pacman hook (sudo);
   - applies (`backup apply` on an untouched Spotify);
   - installs Marketplace and Listening Stats.
3. Change the wallpaper once: DMS writes `color.ini`, Spotify takes the colors.
4. Start Spotify: `lyrics-settings.js` gives Spicy Lyrics its saved settings.
   Install Spicy Lyrics etc. from Marketplace, or paste `marketplace-backup.json`
   with `spice` → Marketplace backup → Restore.

## When something's off

- **Spotify is stock after an update** — `spice` → Repair (the pacman hook
  should have done it: `sudo install -Dm644 ~/Dotfiles/etc/pacman.d/hooks/spicetify.hook /etc/pacman.d/hooks/spicetify.hook`).
- **Colors don't follow the wallpaper** — setting the same wallpaper again
  doesn't regenerate; pick another. A Spotify started before `dms-live.js` was
  on needs one restart.
- **A Marketplace theme instead of the wallpaper colors** — `spice` → Theme → DMS.
  (Marketplace's installer takes a theme name of 3 letters or less for "none";
  that's why the theme is `dms-colors`.)
- **`spice lyrics`: "No Spicy Lyrics settings in Spotify yet"** — Spicy Lyrics
  writes them on the first change in its settings.
