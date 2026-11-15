# Spotify (spicetify)

Spotify painted in the wallpaper colors, plus Marketplace and Listening Stats.
What's installed in Marketplace and Spicy Lyrics' settings are two JSON files
here, exported and imported from Spotify itself.

## How it fits together

```
wallpaper change ─► DMS runs matugen ─► Themes/dms-colors/color.ini
                                            │ post_hook: spicetify refresh -s
                                            ▼
                   <Spotify>/Apps/xpui/colors.css, user.css
                                            │ dms-live.js re-reads them every 2 s
                                            ▼
                                  open Spotify repaints, no restart
```

- `~/.config/spicetify` is a symlink to this folder, as a whole. Whatever
  spicetify, the installers or `spice` write lands here, so a plugin update
  never breaks the link; it only shows up as a change in `git status`.
- `~/.config/matugen` is a symlink to `Dotfiles/matugen`: our own matugen
  template, which DMS runs after its own (`runUserMatugenTemplates`).
- spicetify patches Spotify's files: `/opt/spotify` on Arch, `/usr/share/spotify`
  on Ubuntu (Spotify's apt repo — the flatpak can't be patched). A Spotify update
  undoes the patch; the pacman / apt hook puts it back (`spicetify backup apply`).
- spicetify writes this machine's paths (Spotify, its prefs — with the user
  name) and its `[Backup]` version into `config-xpui.ini`. A git filter blanks
  them in commits and puts this machine's back on a pull, so one config serves
  both machines without conflicts.

## Files

| File | What it is |
|---|---|
| `config-xpui.ini` | spicetify's config: theme `dms-colors`, `extensions`, `custom_apps`. The app installers write it; commit its changes. `spotify_path`, `prefs_path` and `[Backup]` stay blank in git (the filter) |
| `Themes/dms-colors/user.css` | The wallpaper theme: paints Spotify's own color tokens (`--background-base`, `--text-subdued`, the green accent, …) with the matugen colors, mixes 10-20 % of the accent into the near-black DMS surfaces, accent on the play button and progress bars |
| `Themes/dms-colors/color.ini` | The colors themselves, written by DMS on every wallpaper change. Not in git |
| `Extensions/dms-live.js` | Repaints an open Spotify when `colors.css` / `user.css` change (swaps the stylesheet, nothing flashes) |
| `Extensions/lyrics-settings.js` | Adds "Export / Import Spicy Lyrics settings" to the profile menu (Spicy Lyrics has no export of its own) |
| `CustomApps/marketplace/`, `CustomApps/listening-stats/` | Downloaded by their official installers. Not in git: the installer step and `spice` → Update apps put them back |
| `marketplace-backup.json` | What's installed in Marketplace (themes, extensions, snippets): Marketplace → Settings → Back up/Restore → Export, saved here |
| `spicy-lyrics-settings.json` | Spicy Lyrics' settings: profile menu → Export Spicy Lyrics settings, saved here |

Elsewhere in the dotfiles:

| File | What it is |
|---|---|
| `scripts/functions/spicetify.sh` | The `spice` menu |
| `fish/functions/spice.fish` | `spice` in fish |
| `scripts/functions/alias_menu.sh` | "Spotify (spicetify)" in the `asd` menu runs `spice` |
| `scripts/install/apps/spicetify.sh` | The installer's Spicetify step (`configure_spicetify`) |
| `matugen/config.toml`, `matugen/templates/spicetify-color.ini` | The matugen template that writes `color.ini` |
| `etc/spicetify-reapply.sh` | Installed as `/usr/local/bin/spicetify-reapply`: when Spotify is stock (after an install / update), re-applies spicetify as the owner of each `~/.config/spicetify` |
| `etc/pacman.d/hooks/spicetify.hook` | Arch: runs `spicetify-reapply` after `spotify` is installed / updated |
| `etc/apt/apt.conf.d/99spicetify` | Ubuntu: runs `spicetify-reapply` after every dpkg run (it does nothing unless Spotify is stock) |
| `.gitattributes`, `scripts/wrappers/spicetify-config-filter.sh` | The git filter for `config-xpui.ini`; this machine's values wait in `.git/spicetify-machine.ini` |
| `scripts/install/system/sources.sh` | Ubuntu: `install_source_spotify` (Spotify's apt repo), `install_source_spicetify` (release into `/opt/spicetify-cli`, linked to `/usr/local/bin`) |

## `spice`

`spice` in a terminal (or "Spotify (spicetify)" in `asd`) opens the menu; the
line above it shows the custom apps.

| Item | What it does |
|---|---|
| Update apps | Marketplace and Listening Stats: installed version → latest release; outdated or missing ones are preselected. Runs each repo's official installer, which downloads into `CustomApps/` and applies. |
| Repair | Applies spicetify again: `backup apply` when Spotify is stock after an update (what the pacman / apt hook does), else `apply` (e.g. after editing `config-xpui.ini` by hand) |
| Restore stock Spotify | `spicetify restore` (asks first): Spotify without spicetify, e.g. to see if a problem is Spotify's or an extension's. Repair puts spicetify back |

## Plugins and their settings

- **Marketplace's extensions** load from their GitHub repos on
  every Spotify start, so they update by themselves. Marketplace keeps only
  the list of what's installed, inside Spotify — that's `marketplace-backup.json`.
  After installing or removing something: Marketplace → Settings → Back up/Restore
  → Export, save over `Dotfiles/spicetify/marketplace-backup.json`, commit.
- **Spicy Lyrics' settings** live inside Spotify too: profile menu → Export
  Spicy Lyrics settings, save over `Dotfiles/spicetify/spicy-lyrics-settings.json`.
- **Marketplace and Listening Stats themselves** are files in `CustomApps/`,
  not in git: the installer and `spice` → Update apps download them.
- Listening Stats' history: export / import in its own Settings, if you want it.

## New machine

1. Packages (`scripts/install/packages.txt`): `spotify`, `spicetify-cli` (with
   `unzip` for Listening Stats' installer). On Ubuntu: Spotify from its apt repo
   (remove the flatpak `com.spotify.Client` if it's there), spicetify from its
   GitHub release.
2. Installer → Spicetify step:
   - links `~/.config/spicetify` and `~/.config/matugen`;
   - registers the git filter for `config-xpui.ini` in this clone;
   - makes Spotify's folder writable for spicetify (sudo);
   - installs `spicetify-reapply` and the pacman (Arch) or apt (Ubuntu) hook (sudo);
   - applies (`backup apply` on an untouched Spotify);
   - installs Marketplace and Listening Stats.
3. Start Spotify, log in:
   - Marketplace → Settings → Back up/Restore → Import from file →
     `Dotfiles/spicetify/marketplace-backup.json`: installs every plugin from it;
   - profile menu → Import Spicy Lyrics settings → `Dotfiles/spicetify/spicy-lyrics-settings.json`.
4. Change the wallpaper once: DMS writes `color.ini`, Spotify takes the colors.

## When something's off

- **Spotify is stock after an update** — `spice` → Repair. The hook should have
  done it: installer → Spicetify step → the hook substep.
- **`git status` shows `config-xpui.ini` changed, but `git diff` is empty** — the
  file only changed size (spicetify wrote a path); `git add spicetify/config-xpui.ini`
  clears it, nothing is staged.
- **Colors don't follow the wallpaper** — setting the same wallpaper again
  doesn't regenerate; pick another. A Spotify started before `dms-live.js` was
  on needs one restart.
