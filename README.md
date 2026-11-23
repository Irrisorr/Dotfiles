# My Dotfiles for niri WM

Works on **Arch** (and Arch-based: CachyOS, EndeavourOS) and **Ubuntu 26.04** (and Debian-based). One repo for both — the installer detects the distro by itself and installs every package with the right package manager.

# Installation with config/packages choices

- Type in terminal next commands (**IMPORTANT**: clone repo to home directory — `~/Dotfiles` on every machine, all configs and scripts rely on this path):
```
cd ~
git clone https://github.com/Irrisorr/Dotfiles
cd Dotfiles
./install.sh
```

- The package picker and the config menu run in **fzf** (installed automatically; with fzf older than 0.59 the installer falls back to plain gum menus): every category on one screen, `j`/`k` or arrows to move, `Space` to tick, `Ctrl-A` to tick a whole category, `/` or `Ctrl-F` to search. Ticking a package unfolds its dependencies, ticking *Niri* / *Hyprland ecosystem* unfolds what it configures — untick what you don't need. The right panel shows where a package comes from on this distro and whether it is installed (`✓`, `↑` = an update is available)
- Packages: `Enter` shows the install plan and asks; `No` brings the list back with your ticks. Config: `Enter` asks to run the ticked steps (or the one under the cursor), then runs them with their output on screen; the list comes back with `✓` / `✗` and each step's output in its preview. The preview starts with one sentence on what the step does (the `# About:` line above its function)

- After it reboot your device: on the first login a terminal opens with `post_install.sh` by itself (the default terminal from `defapps`; a one-shot user unit the installer leaves on this machine, `dotfiles-post-install.service`, runs `scripts/wrappers/post-install-once.sh` and deletes itself — nothing stays in the configs). A terminal opened before that runs it too (a one-shot fish hook). It has the steps that need an app started by hand first — each one says what to do (start Obsidian / Spotify / iMe, wait for Syncthing, ...) and waits for Enter. The hook runs only in a terminal of the desktop (`$WAYLAND_DISPLAY`), not on a text console: **Obsidian** (vaults from the phone through Syncthing, then the `~/Documents` link and the wallpaper colors), **Spotify** (spicetify can't apply before Spotify's first start), **iMe** (its `tg://` launcher exists after its first start), **Telegram / iMe** (pick the wallpaper theme file and the font once in the client), plus GitHub login, RustDesk (latest release) and Hyprland plugins (only when Hyprland is installed). A config step that can't run yet for such a reason (no vaults, no Spotify prefs, no fingerprint reader) is skipped with a note instead of failing. If something went wrong, you can run it manually:
```
cd Dotfiles
./post_install.sh
```

### On Ubuntu

- Same steps, same menus — nothing to choose by hand. Differences the installer handles by itself:
    - **niri**, `xwayland-satellite` and the **Dux shell** (formerly DankMaterialShell; the Ubuntu package is still called `dms`) come from the author's PPAs (`ppa:duxlabs/dux-repo`, `ppa:duxlabs/dms`) — they are not in the Ubuntu repos. `quickshell` has its own line with `dux-repo`: `dms` needs it from there, so DMS installs even when niri isn't picked. Under DMS also `cava` (the audio visualizer widget) and `qt6-multimedia` (`qml6-module-qtmultimedia` on Ubuntu; DMS's sound effects) — both on in `dms/settings.json`
    - apps that are only in the AUR and work fine sandboxed (Obsidian, Vesktop, Discord, Podman Desktop, Rnote, ...) are installed from **Flathub** — and get a command with the usual name in `/usr/local/bin` (`obsidian`, `discord`, ...), so niri keybinds and the config menu work the same as on Arch
    - **Zen** is upstream's tarball in `~/.local/share/zen` (linked as `/usr/local/bin/zen-browser`), not the flatpak: the flatpak's read-only app dir can't take the Sine bootloader. It is owned by you, so Zen updates itself from inside the browser
    - `clipse` (release binary), JetBrains Mono Nerd Font (official nerd-fonts release), **kitty** (upstream build into `/opt/kitty.app` — apt's 0.45 is too old for this `kitty.conf`; it brings its own `slangc` for custom shaders), Antigravity (Google's tarball, into `/opt/Antigravity`), **spicetify** (upstream release into `/opt/spicetify-cli`, like Arch's package), **gowall** (release binary), **Spotify** (Spotify's own apt repo, not the flatpak: spicetify patches its files), **VS Code** (Microsoft's `.deb`, whose install adds Microsoft's apt repo, so apt updates it; the flatpak's sandbox hides the host's SDKs, docker and git setup from the editor and its terminal, and DMS's theme never reaches it), **IntelliJ IDEA** (JetBrains' snap in classic confinement — no sandbox, snap updates it), **Google Chrome** (Google's `.deb`, which adds Google's apt repo; the flatpak is a community repack that breaks password-manager extensions and security keys), **Telegram** (telegram.org's tarball in `~/.local/share/telegram`, linked as `telegram-desktop`, updates itself; the flatpak sees files only through the portal and wouldn't follow the wallpaper theme), **Zoom** (zoom.us's `.deb`, re-run the package step to update), **iMe** (imem.app's tarball, on Arch too — there is no package: `~/.local/share/ime-desktop`, linked as `ime`, updates itself. Telegram-based apps name their launcher entry `org.ime.desktop._<md5 of the binary's path>`, so a fixed path gives the same entry on every machine with the same home, and `defapps` maps a saved entry to this machine's one when the home differs, so the `tg://` handler in `defapps/mimeapps.list` finds it; the session in `~/.local/share/iMe` is apart from the program), **Zed** (zed.dev's installer: `~/.local/zed.app`, linked as `~/.local/bin/zed`, updates itself; Arch's package calls the command `zeditor`), **Postman** (postman.com's tarball in `~/.local/share/postman`, linked as `postman`, updates itself; `etc/apparmor.d/postman` lets its Electron sandbox use user namespaces, which Ubuntu's AppArmor otherwise refuses). Where one of these was a flatpak before, the installer carries it over — settings, extensions, the Telegram session copied to where the native app looks (nothing overwritten), its `/usr/local/bin` shim removed — and prints the `flatpak uninstall` line to run yourself; **swayimg** (built from the release tag into `/usr/local` — apt's 4.7 predates the Lua config) and FreeOffice (SoftMaker's apt repo) have their own installers in `scripts/install/system/sources.sh`; re-run the package step to update clipse, kitty, the font, Antigravity, spicetify, gowall, swayimg and Zoom (Zen, Telegram, iMe, Zed and Postman update themselves; VS Code, Chrome and Spotify through apt, IDEA through snap)
    - SDDM replaces GDM as the login screen (the **SDDM** config step switches it; it prints the command to switch back)
    - the **Dux greeter** needs Ubuntu 26.04+ (that's the oldest release `ppa:duxlabs/dux-repo` builds it for). Ubuntu's `/etc/pam.d/greetd` has no line starting with `auth` (`@include login`, `-auth ...`), and `dms-greeter install` stops on that ("no auth directive found"): the greeter step first spells the include out as `auth/account/password/session include login`, the same thing, so its fingerprint block goes before the password. It also always reports "Failed to handle gdm3: still in state 'alias'": `gdm3` is an alias of `gdm.service`, which it did disable, so it's harmless (`readlink /etc/systemd/system/display-manager.service` → `greetd.service`); the step answers its "Continue anyway?" and its sudo / run0 question (`DMS_PRIVESC=sudo`) itself
- Known differences:
    - 12 packages have no Ubuntu source and are skipped (the installer names them before installing): `shader-slang` (bundled with the upstream kitty build), `anyrun`, `walker`, `hyprswitch`, `hyprshot`, `arronax`, `vimix-gtk-themes`, `waydroid`, `terminal-rain-lightning`, `logmein-hamachi`, `ags-hyprpanel-git`, `claude-desktop`
    - fingerprint driver (`libfprint-2-tod1-goodix-v2`, 27c6:550a) is installed from the same `.deb` the AUR package repackages — it doesn't update by itself
    - `claude-code` comes from Anthropic's installer (`~/.local/bin/claude`, updates itself); `claude-desktop` has no Linux build and is skipped. **Slack** is the flatpak — apt's `slack` is an unrelated admin tool
- Hardware fixes (both distros):
    - fingerprint (Arch): `libfprint-tod` is built from its AUR PKGBUILD with libfprint's thermal model turned off (its source is a signed git tag: the step first imports the PKGBUILD's `validpgpkeys` into your keyring, which a fresh system doesn't have — otherwise makepkg stops on the signature) — otherwise the Goodix reader is disabled "to prevent overheating" after ~3 min on the lock screen. `pacman -Qi libfprint-tod` shows `(no thermal limit)` on the patched build; an AUR update brings the stock one back, re-run the package step then
    - volume keys (ThinkBook 14 G8 IRL): the keyboard controller sometimes drops the key release, so volume keeps changing. `etc/udev/hwdb.d/61-thinkbook-volume-release.hwdb` makes the kernel release them itself; the **Keyboard fixes (udev hwdb)** config step installs it (a hardware quirk, so the same on Ubuntu). Check: `cat /sys/bus/serio/devices/serio0/force_release` lists `174,176`


### Adding a package

- One line in `scripts/install/packages.txt` under its category — it's installed on both distros. If on Ubuntu the package has another name or comes from somewhere else, add a tail (full format in [INSTALLATION.MD](INSTALLATION.MD#packagestxt)):
```
neovim
sqlite                 ubuntu:apt=sqlite3 (needs for sync private dotfiles)
zen-browser-bin        ubuntu:source=zen (based on firefox | Ubuntu: upstream tarball, updates itself)
logmein-hamachi        ubuntu:skip (VPN service | Ubuntu: .deb at vpn.net, unversioned URL)
```
- Something a package only needs for a feature goes right under it with a `-` — the picker shows it after you pick the package, pre-checked:
```
swayimg                ubuntu:source=swayimg (view images)
- imagemagick (saving rotation of other formats)
```

# Syncing between machines

- Configs are symlinks into `~/Dotfiles`, so the repo **is** the config: change something on one machine, commit & push, then `git pull` on the other one — done
- WM configs never hold distro-specific paths (polkit agent, portals go through `scripts/wrappers/`), so the same niri/hyprland config works on both
- Things that are per machine and need care:
    - monitors (`niri/conf/output.kdl`, `open-on-output` in `workspaces.kdl`) — u can list the monitors of both machines in the same file, niri ignores outputs that aren't connected
    - `fish/fish_variables` is rewritten by fish itself (and depends on its version) — expect it to show up in `git status`
    - `set-env` / `set-java` write into `fish/config.fish`, which is in the repo — f.e. `JAVA_HOME` is `/usr/lib/jvm/java-25-openjdk` on Arch but `/usr/lib/jvm/java-25-openjdk-amd64` on Ubuntu, so don't commit machine-specific values

# Configure 

- All configs u can edit at ur installation directory (`/Dotfiles`) where u cloned this repository. **All configs have symlinks** to itself at `~/.config/` or other directories (such as SDDM config that store at root directory)

# About configuration

### Input (`niri/conf/input.kdl`)

- For touchpad using, there is no mouse configurations
- `Alt` and `Ctrl` are swaped
- `Esc` and `CapsLock` are swaped
- `Super` + `Space` for switching keyboard layout (language)
- Focus follows mouse
- Disabled hot corners at **gestures** property
- tablet mode map for `eDP-1` monitor (u need to change monitor name to yours)

### Output (monitors) (`niri/conf/output.kdl`)

You should change this configuration by urself using command `niri msg outputs` to get names of ur monitors (ex. `eDP-1` or `HDMI-1`) and set necessary flags reading [official wiki](https://yalter.github.io/niri/Configuration%3A-Outputs.html)

### DMS-generated files (`niri/dms/`)

DMS writes these itself from its Settings (keybinds, outputs, layout overrides, cursor, alt-tab, wallpaper blur, ...) and overwrites manual edits. Only the files `niri/config.kdl` includes matter: `dms/binds.kdl` (tracked) and `dms/colors.kdl` (wallpaper colors, regenerated, ignored) — both `optional=true`, so niri also starts before DMS creates them. The rest is ignored by git: niri doesn't load it, and some of it is per machine (`outputs.kdl` lists this PC's monitors — they come from `niri/conf/output.kdl`; DMS applies its own output changes at runtime through `wlr-output-management`, so they last until niri restarts).

### Dux shell plugins (`dms/`)

| Plugin | Source | What it does |
| :--- | :--- | :--- |
| **Bongo Cat** | [hthienloc/dms-plugins](https://github.com/hthienloc/dms-plugins) | Cat in the middle of the bar that taps along with typing |
| **Dank Pomodoro Timer** | [duxlabs-dev/dux-plugins](https://github.com/duxlabs-dev/dux-plugins) | Pomodoro timer widget |
| **Niri Windows** | [rochacbruno/DankNiriWindows](https://github.com/rochacbruno/DankNiriWindows) | Open-window switcher inside the launcher (`Ctrl+Space`, or `!` in the launcher) |
| **Wallpaper Carousel** | [motor-dev/wallpaperCarousel](https://github.com/motor-dev/wallpaperCarousel) | Fullscreen carousel to pick a wallpaper (needs DMS to manage the wallpaper, not swaybg) |

DMS keeps some settings outside `settings.json`, in `~/.local/state/dms/session.json`: the wallpaper transition (`stripes`) and cycling (random, every 5 min), the current wallpaper, and the lock screen / greeter / desktop widget layout. Those keys (`DMS_SESSION_KEYS` in `scripts/install/system/niri.sh`) are kept in `dms/session.json` — `sync.sh dms` (or the `asd` sync menu) copies them there, the wallpaper path with `~` for the home; **Niri ecosystem → Dux shell state** merges them back (stopping DMS meanwhile, it writes the file back from memory). Not in it: launcher history, last player, hidden audio devices, weather location.

Only `dms/plugins.lock.json` (each plugin's repo and commit) and `dms/plugin_settings.json` (their settings) are tracked; the plugin clones in `dms/plugins/` are ignored. `configure_niri` clones them back with `dms plugins restore`. After installing, updating or removing a plugin, refresh the lockfile:

```bash
dms plugins lock
```

Bongo Cat reads the keyboard through `evtest` / `libinput` (`libinput-tools`), so the user has to be in the `input` group — `configure_niri` adds it (re-login to apply).

### Wallpaper colors (matugen)

With Settings → Theme → **Dynamic**, DMS runs [matugen](https://github.com/InioX/matugen) on every wallpaper change: it builds a Material You palette from the wallpaper and fills DMS's templates with it. The scheme (`matugenScheme`) and the per-app templates (`matugenTemplate*`) are in `dms/settings.json`. Our own templates (Spotify, VS Code, Telegram, Obsidian, fish, fzf, clipse, Zed, Chrome) are in `matugen/`: **Niri ecosystem → Dux shell config** links it to `~/.config/matugen`, and DMS runs them together with its own (`runUserMatugenTemplates`), so their files appear with the first wallpaper DMS sets.

| App | Generated file | Hooked up in |
| :--- | :--- | :--- |
| niri (focus ring, border, shadow, tabs, insert hint) | `niri/dms/colors.kdl` | `include` next to `dms/binds.kdl` in `niri/config.kdl` — before its `layout` block, which would override any color it sets, so the gradients there are commented out |
| kitty | `kitty/dank-theme.conf` | `globinclude` in `kitty/kitty.conf` (the old static palette is kept commented) |
| Zen browser | `dms/zen.css` | local Sine mod `zen-browser/chrome/sine-mods/dms-colors`: its script loads the file and reloads it within ~2 s of every change (no Zen restart; needs `sine.allow-unsafe-js` from `user.js`), its CSS lets folders take the color too. Fills the window background, so Zen's workspace gradients don't show |
| Vesktop | `~/.config/vesktop/themes/dank-discord.css` | `configure_vesktop` enables it in Vencord's settings (native install only — the flatpak can't read it) |
| VS Code | the `DankLinux.dms-theme` extension's theme files | `configure_vscode` installs the extension and sets `workbench.colorTheme` (settings.json stays untracked). Our template `matugen/templates/vscode-soften.json` softens the "Dark" and default variants: its `post_hook` (`scripts/wrappers/vscode-soften.sh`) waits for DMS to write them, then moves the backgrounds a step up from near-black (`surface_container_high` for the editor, `surface_container` for the side bar and panel), dims the text to `on_surface_variant` lightened a little and makes comments `outline`. "Light" stays as DMS writes it |
| Telegram, iMe, AyuGram | `~/.local/share/matugen/dms.tdesktop-theme`: our template `matugen/templates/telegram-colors.tdesktop-theme` (Telegram's night theme with its blue-grey surfaces, text and blue accent swapped for the matugen colors; other hues stay) packed by its `post_hook` (`scripts/wrappers/telegram-theme.sh`) with a chat background — a gradient `surface` → `surface_container_low` made by ImageMagick, a step below the incoming bubbles (`msgInBg`: `surface_container_high`) | once per client: Settings → Chat Settings → **Choose from file** → that file → Apply — **post-install → Telegram / iMe** puts the path in the clipboard and lists the clicks. The client watches the applied file and repaints, chat background included, on every change (no restart) |
| Obsidian | `.obsidian/snippets/dms-colors.css` in every vault Obsidian knows (`obsidian.json`): our template `matugen/templates/obsidian-colors.css`, copied there by its `post_hook` (`scripts/wrappers/obsidian-snippet.sh`). It fills the AnuPpuccin theme's `--ctp-custom-*` hooks — greys and text from the matugen surfaces, the accent from `primary`; Catppuccin's other hues (tags, headings, red/green) stay. Without AnuPpuccin the same colors go into Obsidian's own palette (`--color-base-*`, `--accent-h/s/l`): each `--color-base-*` reads AnuPpuccin's `--ctp-*` first and falls back to the wallpaper color, so with AnuPpuccin on nothing changes. Dark mode only | `configure_obsidian` turns the snippet on in every vault (`enabledCssSnippets` in `appearance.json`; Obsidian closed). Obsidian reloads it on every change. Off: Settings → Appearance → CSS snippets → `dms-colors` |
| Qt apps (VLC, Wireshark, OBS, VirtualBox, Octopi, ...) | `qt5ct/colors/matugen.conf`, `qt6ct/colors/matugen.conf` | every Qt app runs with `QT_QPA_PLATFORMTHEME=qt5ct` (`niri/conf/envs.kdl`; qt6ct's plugin answers to that name too, so Qt6 apps get qt6ct): Fusion, the matugen palette, Adwaita icons (the GTK ones too), fonts, open/save dialogs through the portal (dfiles). **Niri ecosystem → Qt apps: wallpaper colors** links `qt5ct/` and `qt6ct/`. Before, the session had `gtk3`, whose Qt5 side gives no colors, and only VLC got qt5ct. An app takes the colors when it starts; the new variable needs a new login. Icons: the config step **Icon theme** picks one of the installed themes (Adwaita, Papirus, ...) for Qt apps, Dux files and the DMS tray (`icon_theme=` in `qt5ct.conf` / `qt6ct.conf`) and GTK (gsettings, `settings.ini`). Dux files has no icon set of its own, it draws the system one; Adwaita lacks many apps' tray icons, Papirus has them. `color_scheme_path` is `~/.config/qt5ct/colors/matugen.conf` (qt5ct / qt6ct expand `~`), so no user name in the repo — saving in the qt5ct GUI writes an absolute path back, don't commit that |
| fish, fzf | `~/.cache/matugen/fish-colors.fish`, `~/.cache/matugen/fzf-colors` from our templates `matugen/templates/fish-colors.fish`, `fzf-colors` | `fish/conf.d/dms-colors.fish`: every open shell sources the fish colors at its next prompt (the path in the prompt is a chip, `on_primary_container` on `primary_container`, readable on any wallpaper) when the file changed, over `config.fish`'s static theme (which stays without it); it points `FZF_DEFAULT_OPTS_FILE` at the fzf one, read by every fzf start. Back to the static theme: remove `conf.d/dms-colors.fish` |
| clipse (`Mod+V`) | `~/.config/clipse/custom_theme.json` (`useCustom: true`) from our template `matugen/templates/clipse-theme.json` | clipse reads it on every start (`themeFile` in `clipse/config.json`). Image previews (`imageDisplay`): `scaleX` / `scaleY` are pixels of image per terminal cell, `heightCut` divides the preview's height for a kitty image, since clipse prints the preview's lines below it — 10 / 18 / 3 keep it whole in this window |
| Zed | `~/.config/zed/themes/dank-soft.json` ("DankShell Soft"), built by our hook `scripts/wrappers/zed-soften.sh` (template `matugen/templates/zed-soften.json`) from DMS's "DankShell Dark" (`dank-zed-theme.json`, `matugenTemplateZed`): surfaces a step up from near-black (`surface_container_high` editor, `surface_container` panels), text a little dimmer, and the syntax in the wallpaper's colors (keywords `primary`, strings `tertiary`, functions `secondary`, types and numbers their `*_fixed`, comments `outline`) — DMS's uses its terminal palette, which the wallpaper hardly moves | `configure_zed` picks `DankShell Soft` (dark) / `DankShell Light` in `settings.json` (untracked, JSONC, edited in place). Zed reloads the theme on change. Back: pick `DankShell Dark` |
| Google Chrome | `~/.cache/matugen/chrome-color` from our template `matugen/templates/chrome-color`: the wallpaper's seed color (`source_color`) | Chrome builds its whole theme from one seed color, as matugen does. `configure_chrome` puts a copy of `google-chrome.desktop` in `~/.local/share/applications` that starts `scripts/wrappers/chrome-theme.sh`, which writes the seed into every profile's `Preferences` (`browser.theme.user_color2`, tonal-spot variant, GTK mode off) while no Chrome runs. So the colors come with Chrome's next start — turn off Chrome's own background running (Settings → System → "Continue running background apps…"), or it never really closes. **Theme sync has to be off** (Settings → You and Google → Sync → Manage → Themes): a synced account theme replaces the local color at start. Back: Chrome → Settings → Appearance → Reset to default, and remove that `.desktop` copy |
| Spotify (spicetify) | `spicetify/Themes/dms-colors/color.ini` from our own template `matugen/templates/spicetify-color.ini` (`matugen/config.toml` → `~/.config/matugen`; DMS runs user templates in the same matugen run as its own, in no set order) | `configure_spicetify`: theme `dms-colors` in `spicetify/config-xpui.ini`; the template's `post_hook` runs `spicetify refresh -s`, the `dms-live.js` extension swaps the colors in an open Spotify within ~2 s (no restart). A pacman / apt hook (`etc/pacman.d/hooks/spicetify.hook`, `etc/apt/apt.conf.d/99spicetify`) re-applies spicetify after every Spotify update. More: [Spotify](#spotify-spicetify) |
| dgop (`dgop top`) | `~/.config/dgop/colors.json` | nothing to do: dgop reads it itself (`keybinds.json` next to it is dgop's own default, not tracked) |
| Dux greeter | — | reads DMS's `dms-colors.json` through `/var/cache/dms-greeter/colors.json`, see [Dux greeter](#dux-greeter-login-screen) |

The generated files inside Dotfiles change with every wallpaper, so they are in `.gitignore`; DMS recreates them on a new machine (after the next wallpaper change). Until then every app falls back to its own colors.

### Layout (`niri/config.kdl`)

- Small gaps (10 px) between window's edges and no background color (transparent)
- Never centered a window when changing focus between windows and always center when only 1 window is on a worskspace
- Default window (column) width is 100%
- Presets for actions like `switch-preset-column-width (Mod+R)` and `switch-preset-window-height (Mod+Shift+R)` are 0.5 (50%) and 1.0 (100%)
- Focus ring around active window (colors from the wallpaper, see above)
- Shadows below windows (u can see them )

### Workspace (`niri/conf/workspaces.kdl`)

- There is 4 named workspaces: **_media**, **browser**, **ide** and **notes**
- They r opened on my specific monitor, so u had to change the name of monitor to urs (at `open-on-output "<here ur monitor name>"`)
- Workspaces are sorted **alphabetically**, so i had to add `_` in **_media** if i wanted this worspace to be the first

### Window/Layer rules (`niri/conf/rules.kdl`)

- **Corner radius** for all windows is 18
- **Indicate screencasted windows** with red colors
- Rules about a page, chat or dialog match its **title alone**, without an app-id, so they hold in any browser or Telegram client and `defapps` has nothing to copy for them; app-ids only where the app itself is meant (workspaces, clipse, terminals, Obsidian, Telegram calls)
- Some apps that **blocked from screencasting** (u can add ur apps if u want): bank pages by title (`santander|erste|centrum24|logowanie`), saved passwords (`Пароли — ` / `Passwords — `), Saved Messages in Telegram / iMe / AyuGram (`Избранное`), plus Zen while a page loads — its title is the bare `Zen Browser` for 15-335 ms between pages, so every page load in Zen is black for that moment in a screencast, clipse
- **This PC's own rules** go in `niri/conf/sensitive_rules.kdl` (gitignored, included with `optional=true` — fine if it's missing): rules you don't want in git, like blocking your mail or notes from screencasting
- Apps that should open on the **_media / browser / ide / notes** workspace
- **Picture in picture** always floating (by title: `Picture-in-Picture` / `Картинка в картинке`)
- **Clipse** always opens floating and small size
- **Terminal** (kitty, and whatever defapps added) always opens at 50% (0.5) window size proportion
- **Obsidian** has scroll-factor 0.2
- **Telegram, iMe**: a new window of theirs takes focus, so an incoming call comes up in front (its window has only the contact's name as title, so every new window does, except at login)
- **VLC** isn't sized by a rule: it resized its window to the video (wider than the column for 1080p) — `configure_vlc` turns that off in `vlcrc`
- **Rofi** has blur effect
- **Wallpaper** has place-within-backdrop rule (see in [niri wiki](https://niri-wm.github.io/niri/Overview.html#backdrop-customization))
- **All apps** that use Wayland protocol have blur effect

### Animations (`niri/conf/animations.kdl`)

- Default niri animations

### Blur (`niri/config.kdl`, `niri/conf/rules.kdl`)

- Blur for all windows
- Global setting for blur in `niri/config.kdl`

### Autostart (`niri/conf/autostart.kdl`)

- **wl-clipboard** for clipboard history
- **polkit-mate** for authenticate apps (started through `scripts/wrappers/polkit-agent.sh`, because the agent's path differs per distro)
- **dms** - panel bar (Dux shell, formerly DankMaterialShell; the command is still `dms`)
- **swaybg** - wallpaper tool
- **syncthing** - local server for synchronize folders between laptop and phone or another devices in real time
    - started as `syncthing serve --no-browser` (niri and Hyprland autostart), so it doesn't open its web UI in the browser on every login — that's http://127.0.0.1:8384 when needed
    - syncs `~/Obsidian` with the phone. Documents live in the vault, `~/Obsidian/Быт/Документы`, and `~/Documents` is a link to it: Syncthing doesn't follow symlinks and Android has none, so the real folder has to be inside the synced one. The config step **Documents -> Obsidian vault** makes the link (merges a real `~/Documents` in first, stops on a file with the same name and other content)
    - `~/Obsidian/.stignore` (not in the dotfiles, Syncthing doesn't sync it either — add the same line on the phone): `(?d).obsidian/plugins/recent-files-obsidian/data.json` — the plugin rewrites it on every opened note on each device, so it only made conflicts; `(?d)` lets Syncthing delete it with its folder, without it a deleted vault stays on the other device
- **clipse** - clipboard app
    - history expires by time through our timer, not clipse's own `deleteAfter`: in clipse 1.2.1 that one only runs when the history is read (opening `Mod+V`, a new copy), removes by indexes that shift after every removal — so each run drops about every other expired item and may hit a pinned one — and leaves the items' images in `tmp_files`. So `clipse/config.json` has `deleteAfter: 0` and our own `pruneAfter` (seconds, 14400 = 4 h); `systemd/user/clipse-prune.timer` runs `scripts/wrappers/clipse-prune.sh` every 5 min: drops unpinned items older than that and images no item points to. Config step **Clipse → Expire history on time** links the units into `~/.config/systemd/user` and enables the timer
- kill all **xdg-desktop-portals** for rerun while startup to avoid unexpected problems during the session

### Environment (`niri/conf/envs.kdl`)

- `ELECTRON_OZONE_PLATFORM_HINT "auto"` - Force Electron applications (like VS Code, Discord, Obsidian) to automatically detect and use the native Wayland display server on Linux
- `QT_QPA_PLATFORM "wayland"` - Force Qt-based applications (like KDE apps, VLC, OBS) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `ELECTRON_ENABLE_WAYLAND "1"` - Forces Electron applications to run natively on the Wayland display protocol 
- `MOZ_ENABLE_WAYLAND "1"` - Force Mozilla applications (like Firefox) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `GDK_BACKEND "wayland"` - Force GTK applications (like Gnome apps) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `OBSIDIAN_USE_WAYLAND "1"` - Force Obsidian to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `QT_QPA_PLATFORMTHEME "qt5ct"` - Qt applications take qt5ct / qt6ct: the wallpaper palette, Fusion, portal dialogs (see Wallpaper colors; was `gtk3`, which gave Qt5 no colors)

### Dux greeter (login screen)

- The [Dux greeter](https://duxlabs.dev/docs/dms-greeter/installation) (`dux-greeter-bin` from the AUR, `dux-greeter` from `ppa:duxlabs/dux-repo` on Ubuntu 26.04+) runs DMS's login screen under greetd and replaces SDDM
- **Niri ecosystem → Dux greeter** in the config menu runs `dms-greeter install --yes`: installs greetd, sets `/etc/greetd/config.toml`, disables the old display manager, adds you to the `greeter` group, gives that group read access to `~`, `~/.config`, `~/Dotfiles` and the DMS state, and links `/var/cache/dms-greeter/{settings,session,colors}.json` to your live DMS files
- So the login screen follows DMS: wallpaper, matugen colors, fonts and the `greeter*` keys in `dms/settings.json` — its own widget layout (`greeterWidgetInstances`, `greeterFollowLockScreen: false`, edited in Settings → Greeter), and fingerprint login (`greeterEnableFprint` writes the `pam_fprintd` line into `/etc/pam.d/greetd` on sync)
- The group applies after the next login; until then `dms-greeter status` can't read `/var/cache/dms-greeter` and reports the links as missing
- After toggling fingerprint/U2F in Settings → Greeter: `dms-greeter sync`. Logs: `journalctl -t dms-greeter/niri -b`, `journalctl -t dms-greeter/session -b`. Back to the previous display manager: `dms-greeter uninstall`
- Fingerprint at the greeter: dms-greeter writes `pam_fprintd.so max-tries=2 timeout=10` into `/etc/pam.d/greetd`, so the reader gives up 10 s after the greeter appears. The optional action **Niri ecosystem → Dux greeter: wait 5 min for a fingerprint** (not ticked with the step, tick it on machines with a reader) sets `timeout=300`; typing the password still logs in at once. `dms-greeter sync` and the fingerprint toggle write `timeout=10` back, so re-run it after them

### Dux calendar (`dankcal/`)

- [Dux calendar](https://duxlabs.dev/docs/dcal/installation) (`dcal`, `dux-calendar-bin` from the AUR, `dux-calendar` from `ppa:duxlabs/dux-repo` on Ubuntu 26.04+) is DMS's calendar backend (`calendarBackend: "dankcal"` in `dms/settings.json`); no autostart entry is needed
- **Niri ecosystem → Dux calendar config** links `dankcal/` to `~/.config/dankcal` — only the UI settings (`ui-settings.json`). Accounts, tokens and the event cache are per machine (`~/.local/share/dankcal`), so add the Google account again: `dcal account add google`
- Google Tasks come through the shared built-in OAuth client, whose daily Tasks API quota can run out (log: `Google Tasks failed ... retry deferred`, fixes itself at midnight Pacific). For your own quota: `dcal account setup google`, then `dcal account add google --client-id ... --client-secret ...`

### Dux files (`dfiles/`, `xdg-desktop-portal/`)

- [Dux files](https://duxlabs.dev/docs/dfiles/desktop-integration) (`dfiles`, `dux-files-bin` from the AUR, `dux-files` from `ppa:duxlabs/dux-repo` on Ubuntu 26.04+)
- **Niri ecosystem → Dux files config** links `dfiles/` (settings `ui-settings.json`, sidebar `bookmarks.json`) to `~/.config/dfiles`, makes it the default file manager (`xdg-mime default dev.duxlabs.files.desktop inode/directory`) and links `xdg-desktop-portal/niri-portals.conf`, so other apps' open/save dialogs are Dux files windows (`FileChooser=dfiles;gnome;gtk;`)
    - `bookmarks.json` needs absolute paths (Dux files drops a `~` one), so the repo keeps `@HOME@` / `@USER@` in their place: the git filter `home-path` (`.gitattributes`, `scripts/wrappers/home-path-filter.sh`) writes them on commit and puts this machine's home back on checkout. The same step registers it in the clone (`git config filter.home-path.*`) and fills in a file checked out before that
- Open tabs, folder views and folder badges are in `~/.local/state/dfiles` and stay per machine

### SDDM (`sddm/`)

- Theme **corners** — based on [aczw/sddm-theme-corners](https://github.com/aczw/sddm-theme-corners), ported to **Qt6** (upstream is Qt5-only), so the same theme works on Arch and Ubuntu (Ubuntu's sddm has only the Qt6 greeter)
- Greeter runs on **Wayland** (`DisplayServer=wayland`, `weston --shell=kiosk` as its compositor) — no X server needed
- Preview the theme in a window without logging out:
```
sddm-greeter-qt6 --test-mode --theme ~/Dotfiles/sddm/corners
```
- `configure_sddm` copies the theme and `default.conf` into the system dirs, so after editing them re-run the **SDDM** step in `./install.sh`

### Spotify (`spicetify/`)

Spotify painted in the wallpaper colors, plus Marketplace and Listening Stats.
What's installed in Marketplace and Spicy Lyrics' settings are two JSON files
in `spicetify/`, exported and imported from Spotify itself.

#### How it fits together

```
wallpaper change ─► DMS runs matugen ─► spicetify/Themes/dms-colors/color.ini
                                            │ post_hook: spicetify refresh -s
                                            ▼
                   <Spotify>/Apps/xpui/colors.css, user.css
                                            │ dms-live.js re-reads them every 2 s
                                            ▼
                                  open Spotify repaints, no restart
```

- `~/.config/spicetify` is a symlink to `Dotfiles/spicetify`, as a whole. Whatever
  spicetify, the installers or `spice` write lands here, so a plugin update
  never breaks the link; it only shows up as a change in `git status`.
- `~/.config/matugen` is a symlink to `Dotfiles/matugen` (Niri ecosystem → Dux
  shell config): our own matugen templates, which DMS runs together with its own
  (`runUserMatugenTemplates`).
- spicetify patches Spotify's files: `/opt/spotify` on Arch, `/usr/share/spotify`
  on Ubuntu (Spotify's apt repo — the flatpak can't be patched). A Spotify update
  undoes the patch; the pacman / apt hook puts it back (`spicetify backup apply`).
- spicetify writes this machine's paths (Spotify, its prefs — with the user
  name) and its `[Backup]` version into `config-xpui.ini`. A git filter blanks
  them in commits and puts this machine's back on a pull, so one config serves
  both machines without conflicts.

#### Files (`spicetify/`)

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

#### `spice`

The menu: update Marketplace / Listening Stats, Repair, Restore stock — see [Scripts](#scripts-just-type-name-of-script-in-terminal-or-use-asd-menu).

#### Plugins and their settings

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

#### New machine

1. Packages (`scripts/install/packages.txt`): `spotify`, `spicetify-cli` (with
   `unzip` for Listening Stats' installer). On Ubuntu: Spotify from its apt repo
   (remove the flatpak `com.spotify.Client` if it's there), spicetify from its
   GitHub release.
2. Installer → Spicetify step:
   - links `~/.config/spicetify` (`~/.config/matugen` comes with Niri ecosystem → Dux shell config);
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

#### When something's off

- **Spotify is stock after an update** — `spice` → Repair. The hook should have
  done it: installer → Spicetify step → the hook substep.
- **`git status` shows `config-xpui.ini` changed, but `git diff` is empty** — the
  file only changed size (spicetify wrote a path); `git add spicetify/config-xpui.ini`
  clears it, nothing is staged.
- **Colors don't follow the wallpaper** — setting the same wallpaper again
  doesn't regenerate; pick another. A Spotify started before `dms-live.js` was
  on needs one restart.

### Aliases (`fish/functions/*`)

> Right now there is only **fish** shell aliases, but u can add shell scripts for other shells too using their functions

- Each alias is its own file in `scripts/functions/<func_name>.sh` (one function per file)
- You can run aliases by it's name in terminal (see below)
- You can run menu with all aliases by typing `asd` in terminal and choose needed script
- Every menu in the repo is one universal `menu` function (`scripts/lib/helpers.sh`). You pass it `"Label|function"` entries (optionally `"Label|function|guard"` to hide an entry unless the guard passes: a command name, `distro:arch` / `distro:debian`, or `test:<function>`; join several with `+`). The **label** is decoupled from the function name, so `package_commands` can show as `System packages`
- A menu entry whose function calls `menu` again becomes a **submenu** with its own back button — that's how `System packages` (`scripts/functions/system_packages.sh`) opens `System update` / `System upgrade`
- Adding an alias = drop a `scripts/functions/<name>.sh` file defining its function, then add one `"Label|<func>"` line to the `menu` call in `scripts/functions/alias_menu.sh`
- Shared path constants and includes (`DOTFILES_DIR`, `PRIVATE_DIR`, `CONFIG_DIR`, the gum/print helpers, ...) live in `scripts/lib/common.sh` — source it instead of repeating paths

### Repo layout

The two entry points sit at the repo root; everything else lives under `scripts/`:

```
Dotfiles/
  install.sh         # the installer MENUS only (sources the engine, then config_menu + first menu)  (./install.sh)
  post_install.sh    # runs once after reboot: ./post_install.sh
  systemd/user/      # user units linked into ~/.config/systemd/user by config steps (clipse-prune.timer)
  etc/               # system files copied into /etc by config steps (udev hwdb keyboard fixes; spicetify-reapply + its pacman / apt hook; AppArmor profile for Postman's tarball on Ubuntu)
  scripts/
    lib/             # reusable helpers (no app-specific logic)
      common.sh      # path constants + sources lib/  (source this everywhere)
      distro.sh      # distro detection + package managers (pacman/yay/apt, flatpak, snap, PPAs)
      paths.sh       # paths that differ between distros (polkit, portals, sddm, fish, ...)
      gum.sh         # gum bootstrap + UI wrappers
      helpers.sh     # universal menu(), execute_*, create_symlink, package engine, system_update
      fzf.sh         # shared parts of the fzf pickers (modes, keys, footer) + fzf bootstrap
    wrappers/        # launchers called from WM configs, resolve distro-specific paths (polkit, portals); git's filter for spicetify/config-xpui.ini; matugen's hooks (VS Code, Telegram, Obsidian, Zed themes); Chrome's launcher; clipse's history expiry (clipse-prune.sh)
    install/
      main.sh        # installer ENGINE: sourcing + core-step functions + run_final_steps (no menus)
      packages.txt   # one line per package, works for both distros
      fzf_picker.sh  # fzf package picker (run on its own to try it: installs nothing)
      fzf_config.sh  # fzf config menu (run on its own: dry run)
      system/        # system-level config functions: niri (+ Dux shell, plugins, greeter), hyprland, sddm, fingerprint, hwdb, gtk/bluetooth/polkit, xdg, flatpak, sources.sh (custom installers)
      apps/          # per-app config functions: zen, kitty, fish, thunar, rofi, ...  (ONE file per app)
    functions/       # everyday shell aliases + alias_menu.sh (the `asd` menu)
      sync/          # sync.sh: copies live configs back into Dotfiles (modules/ + sync_map.json, see below)
```

A script that needs its own folder (assets, a JSON config, ...) just gets a
subfolder under `functions/` — the `asd` menu sources every `*.sh` recursively
and ignores everything else (so `sync/sync_map.json` is left alone).

Every menu is one universal `menu` function (`scripts/lib/helpers.sh`) fed
`"Label|function[|guard]"` entries. `install.sh` holds **only the menus**: it
sources the engine (`install/main.sh`), then declares `config_menu` and the first
menu, then calls `run_final_steps`. The first menu lists the core steps plus a
`config_menu` entry; picking it opens the config submenu (a function that calls
`menu` again, so it gets a back button automatically). Each config action is a
`configure_*` function in its own file under `scripts/install/apps/` (or
`system/`); the engine sources them all. Want to change how an app is configured?
Edit its single file. Add a new one? Write `configure_<name>` in a file there and
add one line to `config_menu` in `install.sh` — the engine is never touched.

#### Scripts (just type name of script in terminal or use `asd` menu)

- `asd` - Menu with all useful scripts by choosing from list:
    - `set-env <var_name> <var_value>` - Set a new environment variable (writes to `config.fish`; with no args it asks via `gum`). Applied in the current shell right away, no restart needed
    - `delete-env <var_name>` - Delete an environment variable (with no args it lets you pick via `gum`). Removed from the current shell right away
    - `set-java` - Set Java environment variable with selection from existing java versions (check `/usr/lib/jvm/`)
    - `rain` - Rain animation (if installed `terminal-rain` package)
    - `rain-float` - Rain animation in mini floating window (if installed `terminal-rain` package)
    - `vim` - open **nvim** on **ide** workspace and maximize window (if installed `neovim` package)
    - `Sync to Dotfiles` (`scripts/functions/sync/sync.sh`) - menu of sync modules: Zen Sine mod settings, Dux shell state (`dms/session.json`), the files in `sync_map.json` (`sync-private` runs just the latter; see below)
    - 'System packages' - update / upgrade on both distros:
        - `update` - sync package lists (`yay -Sy` / `apt update`)
        - `upgrade` - install all updates: `yay -Syu` / `apt full-upgrade`, plus `flatpak update` (asks before installing, like running them by hand)
    - 'Image tools (gowall)' (`scripts/functions/gowall.sh`, if `gowall` is installed) - every gowall feature with a description before each one:
        - `gw` - the menu; `gw <image>` - straight to editing that image
        - Edit an image: recolor to a theme, replace a color, invert, format, brightness/contrast/gamma/saturation, grayscale, flip/mirror, 3D tilt, pixel art, border/grid/round corners, resize, compress, AI upscale, remove background. Every change opens in `swayimg` first: keep it, retry with other settings or drop it; changes stack, Undo goes back one. History lists every version of the session (dropped tries too) with what was done and an image preview in fzf; any of them can be opened, saved or continued from. Nothing reaches `~/Pictures/gowall` until Finish → Save (or Save and set as wallpaper through DMS, or copy to clipboard)
        - Also: the same change on many images (previewed on the first), stack images / make a GIF, OCR (image or PDF; local `tesseract` comes with the packages — `tesseract-data-eng`/`-rus` (Ubuntu: `tesseract-ocr-eng`/`-rus`), language `eng+rus` for both; other providers and keys: [gowall docs](https://achno.github.io/gowall-docs/ocr/introduction)), palette of an image, themes and their colors, color tools (blend, lighten/darken, variants, color wheel, gradient image), recolor an SVG/ICO icon, wallpaper of the day (the top r/wallpaper post of the day, read from the RSS feed like gowall's master does: `gowall -w` in 0.2.4 gets 403 from Reddit)
        - Images come from the current wallpaper, the clipboard (a niri screenshot lands there), fzf over `~/Pictures` (with a preview in kitty) or a typed path
        - Edits go through gowall's stdout; compress, upscale, stack, gif and bg write a temp file instead (they can't use stdout, or ask to download a model on the first run)
        - Something missing (tesseract, its language, rsvg-convert, magick, ollama, …) → it says what to install, with this distro's package names. On Ubuntu gowall itself is the release binary in `/usr/local/bin` (installer's package step)
    - `defapps` - 'Default apps' (`scripts/functions/default_apps.sh`): which app opens what; a menu with two parts. Every installed app is offered, also hidden ones (swayimg) and ones that don't claim the type (VS Code for text). Choices go to `~/.config/mimeapps.list` — the file DMS Settings → Default apps, `xdg-open`, the portals and dfiles read; "Ask every time (DMS chooser)" is DMS's own picker (`dms-open`)
        - **Default apps** — the roles DMS has (terminal, browser, file manager, text editor, image viewer, video, music, PDF, mail, calendar), each writing the same group of types DMS writes, so both show the same. Terminal has no file type: it goes first in `~/.config/xdg-terminals.list` (read by DMS for `Terminal=true` apps and by `xdg-terminal-exec`). The preview says what each role does and doesn't affect — e.g. "Show in folder" is the `org.freedesktop.FileManager1` D-Bus service, not mimeapps.list
        - Terminal, browser and file manager follow niri: on every start `defapps` reads their binds in `niri/conf/binds.kdl` (`Mod+Return`, `Mod+B`, `Mod+E`), finds the app each starts (by Exec, else by package: `zen-browser` → `zen.desktop`) and makes it the default everywhere — so editing a bind by hand carries over; what was taken is shown at the top. It also sets the bind's title to what it starts (`Terminal (Alacritty)`) and rewrites binds that run a command inside a terminal (`Mod+V`: `kitty --class clipse -e 'clipse'` → `alacritty --class clipse -e 'clipse'`, class kept so window rules still match; kitty, alacritty, foot, wezterm). Window rules in `niri/conf/rules.kdl` and `niri/conf/sensitive_rules.kdl` (if there is one) cover the new app too: next to every match line of another app of the same kind (another terminal, browser, file manager) that matches by app-id alone goes a copy with the new app's app-id — a line with a title isn't copied (such rules match by title alone, see [Window/Layer rules](#windowlayer-rules-niriconfruleskdl)) — (taken from its open window via `niri msg windows`, else `StartupWMClass`, else the desktop id), rest of the line kept, and the comment above the rule gets the name added; nothing is added where a line already matches the new app (`r#"(?i)chrome"#` covers google-chrome), so switching back and forth changes nothing. The rules themselves match case-insensitive substrings (`app-id=r#"(?i)obsidian"#`, `title=r#"(?i)santander"#`), so a renamed app-id (Obsidian 1.15: `md.obsidian.Obsidian`) or a flatpak id still matches; only clipse is exact (`(?i)^clipse$`, it would catch Eclipse). Picking one of them in `defapps` rewrites that bind line in place (title and spawn; reverted if `niri validate` fails). A role set to "Ask every time" stays, a bind can't ask. `Mod+C` stays VS Code
        - **File types** — categories (Your extensions, Images, Text & code, Video, Audio, PDF & books, Office, Archives, Web & links, Folders, Calendar, All types) fold open with Enter/Tab; each row is one MIME type with its extensions and what opens it now: plain = chosen by you, gray `(system: …)` = nobody chose, red `✗ missing` = the chosen app isn't installed, `via` = taken from the parent type (e.g. text/plain for .py)
        - Enter on a row picks its app; Space ticks rows (on a category: all of it) and Alt+Enter picks one app for the ticked ones, or for the whole category under the cursor. Ctrl-R resets to what the system picks
        - Extensions come from shared-mime-info (`/usr/share/mime`, updated by packages), read on every start — a package that adds a type shows up by itself. **Your extensions → + Add extension** handles the rest: an unknown extension gets its own type (`application/x-<ext>`) or opens like an existing one (`.conf` as text/plain); a known one can be split off into its own type. Stored in `~/.local/share/mime/packages/defapps.xml` (then `update-mime-database`); Ctrl-D removes one
        - **Dotfiles:** on exit `defapps` saves this machine's choices to `defapps/` — `mimeapps.list` (only `[Default Applications]`; entries of apps not installed here, kept from another PC, stay) and `xdg-terminals.list`; `defapps.xml` lives there and the mime dir links to it. Changes made in DMS get saved on the next `defapps` run. The installer step **Default apps (defapps)** puts them back: links the extensions (+ `update-mime-database`), merges the saved defaults into `~/.config/mimeapps.list` for the apps installed (lists the skipped ones, the rest of the file stays) and writes the terminal order
        - Ubuntu: flatpak apps are found right after the installer put them in (before the next login adds them to `XDG_DATA_DIRS`), and a default saved under an app's Arch id finds its Ubuntu package or flatpak (`vesktop.desktop` ↔ `dev.vencord.Vesktop.desktop`, also Obsidian, Chrome's old flatpak, IntelliJ's snap `intellij-idea-ultimate_intellij-idea-ultimate.desktop`, and VS Code: `com.microsoft.VSCode.desktop` ↔ `code.desktop` of Microsoft's `.deb` — the `DA_SAME_APP` table) and back. Telegram-based clients (iMe, Telegram's tarball) name their launcher after a hash of the binary's path (`org.ime.desktop._<md5>.desktop`), which changes with the home directory: a saved one of those finds this machine's launcher of the same client, so `tg://` works under another user name too
    - `fonts` - 'Fonts' (`scripts/functions/fonts.sh`): one interface font, one monospace font and the interface size, written to every place that keeps its own; the menu shows each place and ✓ / ✗ against the choice. Fonts are picked in fzf with a sample drawn in the font itself (kitty)
        - **fontconfig** (`fontconfig/fonts.conf` → `~/.config/fontconfig`): what `sans-serif`, `serif`, `system-ui` and `monospace` mean — Electron apps, niri's hotkey overlay, alacritty, web pages and everything else that asks for a generic family
        - **GTK** (gsettings `font-name` / `document-font-name` / `monospace-font-name`, `gtk-font-name` in `settings.ini`), **Qt** (`qt5ct/`, `qt6ct/` — every Qt app), **DMS** (`fontFamily`, `monoFontFamily` in `dms/settings.json`; it was "Fira Code", which isn't installed), **Zen** (`font.name.*` in `zen-browser/user.js`, on Zen's next start), **kitty** (`font_family`, reloaded at once), **VS Code** (editor and terminal font; an old flatpak install's settings under `~/.var/app` while there is no `~/.config/Code`)
        - The choice lives in the dotfiles (families in `fontconfig/fonts.conf`, size in `qt5ct.conf`); the installer's Fonts step links `fontconfig/` and writes GTK and VS Code from them. Telegram and Obsidian (Appearance → Font) keep their own, set them there — post-install's Obsidian and Telegram / iMe steps say which. The Fonts step first checks that the chosen families are installed and installs JetBrains Mono Nerd (`ttf-jetbrains-mono-nerd`) if it's missing — otherwise every place would name a font fontconfig quietly replaces
    - `spice` - 'Spotify (spicetify)' (`scripts/functions/spicetify.sh`), the whole setup: [Spotify](#spotify-spicetify)
        - Update apps — Marketplace and Listening Stats: installed → latest version, outdated ones preselected; runs each repo's official installer
        - Repair — applies spicetify again: `backup apply` when Spotify is stock after an update (what the pacman / apt hook does), else `apply`
        - Restore stock Spotify — removes spicetify (asks first), to see whether a problem is Spotify's or a plugin's; Repair puts it back
        - Plugins and Spicy Lyrics settings aren't in the menu: they are exported / imported in Spotify itself (`spicetify/marketplace-backup.json`, `spicetify/spicy-lyrics-settings.json`)

#### Syncing live configs back (`scripts/functions/sync/`)

- `sync.sh` lists the modules in `modules/` (fzf menu, Space ticks several); `sync.sh <name>...` runs them without the menu. A new `modules/<name>.sh` with `SYNC_TITLE`, `SYNC_DESC` and `sync_module` shows up on its own
- `zen` - the settings of the Sine mods (only their own `prefs.js` keys) → `zen-browser/sine-prefs.js`; the mods themselves live in `zen-browser/chrome` (the profile's `chrome` links there). The other way round is `configure_zen` (config menu): it links `zen-browser/*` into the profile (`chrome/` as a whole), installs Sine with its official `updater.sh` (native package only — it asks for root for the bootloader in `/opt`) and writes `sine-prefs.js` back into `prefs.js`
- `dms` - the Dux shell state kept outside `settings.json` (wallpaper transition and cycling, lock screen / greeter layout) → `dms/session.json`, see [Dux shell plugins](#dux-shell-plugins-dms)
- `map` - the files in `sync_map.json` (`sync-private` runs just this one):
- Sensitive profile data (Zen sessions, etc.) lives in a separate **private** repo (`~/Dotfiles-private`), not here
- `scripts/functions/sync/sync_map.json` is an array of two kinds of entry:
    - **file group**: `{ "dest": "~/Dotfiles-private/zen-browser", "sources": ["fileA", "folderB", ...] }` — files or folders (copied recursively), `~` and `*` globs supported
    - **sqlite table**: `{ "dest": "...", "sqlite": "~/.../places.sqlite", "table": "zen_bookmarks_workspaces" }` — backs up just one table (dumped to `<table>.sql`) instead of the whole DB
    - an optional `"comment"` field per object is ignored
- Run `sync-private` (or pick it from the `asd` menu) to sync into the private repo, then commit/push it (needs `jq`; sqlite entries need `sqlite3`). Files that already exist in a dest are shown in one gum selection, all pre-selected — **unselect** the ones you want to keep instead of overwriting


# Key Bindings

### Apps

| Keybinding    | App                         |
| :---          | :---                        |
| `Mod+Return`  | Kitty (Terminal)            |
| `Mod+B`       | Zen Browser (Browser)       |
| `Mod+E`       | Nautilus (File Explorer)    |
| `Mod+C`       | VSCode                      |
| `Mod+N`       | Obsidian (Notes)            |
| `Mod+M`       | Spotify (Music)             |
| `Mod+Shift+T` | iMe (Telegram client)       |
| `Mod+D`       | Vesktop (Discord client)    |
| `Mod+V`       | Clipse (Clipboard)          |

### Dux shell (DMS)

These live in `niri/dms/binds.kdl`, which DMS writes itself (Settings → Keybinds) and which `niri/config.kdl` includes after `conf/binds.kdl` — so for the same key DMS wins. The rofi / Hyprlock / Wlogout / volume binds it replaced are kept commented out in `conf/binds.kdl`.

| Keybinding                 | Action                         |
| :---                       | :---                           |
| `Alt+Space`                | Application Launcher           |
| `Ctrl+Space`               | Switch Windows (Niri Windows)  |
| `Mod+Comma`                | Settings                       |
| `Mod+L`                    | Lock Screen                    |
| `Mod+Shift+L`              | Power Menu                     |
| `Mod+Shift+M`              | Task Manager                   |
| `Mod+Shift+N`              | Notepad                        |
| `Mod+Shift+W`              | Browse Wallpapers              |
| `Mod+Alt+W`                | Wallpaper Carousel             |
| `Mod+Shift+/`              | Keybinds Cheatsheet            |
| `XF86AudioRaiseVolume`     | Volume +5%                     |
| `XF86AudioLowerVolume`     | Volume -5%                     |
| `XF86AudioMute`            | Toggle Mute                    |
| `XF86AudioMicMute`         | Toggle Mic Mute                |
| `XF86MonBrightnessUp`      | Brightness +5%                 |
| `XF86MonBrightnessDown`    | Brightness -5%                 |
| `Mod+XF86AudioRaiseVolume` | Media: Next Track              |
| `Mod+XF86AudioLowerVolume` | Media: Previous Track          |
| `Mod+XF86AudioMute`        | Media: Play / Pause            |

### Window's actions

| Keybinding        | Action                           |
| :---              | :---                             |
| `Mod+Q`           | Close Window                     |
| `Mod+R`           | Switch Preset Column Width (50/100 %)       |
| `Mod+Shift+R`     | Switch Preset Window Height (50/100 %)      |
| `Mod+Ctrl+R`      | Reset Window Height              |
| `Mod+F`           | Maximize Column                  |
| `Mod+Ctrl+Shift+F`| Toggle Windowed Fullscreen (fake)|
| `Mod+Shift+F`     | Fullscreen Window                |
| `Mod+Ctrl+F`      | Expand Column to Available Width |
| `Mod+Tab`         | Focus Previous Window            |
| `Mod+Left`        | Focus Left Window                |
| `Mod+Right`       | Focus Right Window               |
| `Mod+Shift+Left`  | Move Window Left                 |
| `Mod+Shift+Right` | Move Window Right                |
| `Mod+Shift+Down`  | Move Window to Workspace Down    |
| `Mod+Shift+Up`    | Move Window to Workspace Up      |
| `Mod+G`           | Toggle Column Tabbed (Group)     |
| `Mod+Shift+G`     | Consume window into group        |
| `Mod+Ctrl+G`      | Expel window from group          |
| `Mod+T`           | Toggle Window Floating           |
| `Mod+Minus`       | Window Width -10%                |
| `Mod+Equal`       | Window Width +10%                |
| `Mod+Shift+Equal` | Window Height +10%               |
| `Mod+Shift+Minus` | Window Height -10%               |
| `Mod+Shift+TouchpadScrollLeft`  | Window width +5%   |
| `Mod+Shift+TouchpadScrollRight` | Window width -5%   |
| `Mod+Shift+TouchpadScrollUp`    | Window height +5%  |
| `Mod+Shift+TouchpadScrollDown`  | Window height -5%  |


### Workspace's actions

| Keybinding | Action |
| :---                  | :---                           |
| `Mod+O`               | Toggle Overview                |
| `Mod+Down`            | Switch Workspace Down          |
| `Mod+Up`              | Switch Workspace Up            |
| `Mod+Ctrl+Down`       | Move Workspace Down            |
| `Mod+Ctrl+Up`         | Move Workspace Up              |
| `Mod+Shift+Page_Up`   | Move Workspace to Monitor Up   |
| `Mod+Shift+Page_Down` | Move Workspace to Monitor Down |
| `Mod+[1-9]`           | Focus Workspace [1-9]          |
| `Mod+Ctrl+[1-9]`      | Move Column to Workspace [1-9] |

### Others

| Keybinding               | Action                      |
| :---                     | :---                        |
| `Mod+Shift+S`            | Screenshot (Ctrl+C to copy) |
| `Mod+Shift+End`          | Screenshot Screen           |
| `Mod+End`                | Screenshot Window           |
| `Mod+Backspace`          | Pick Window for Screencast  |
| `Mod+Shift+Backspace`    | Pick Monitor for Screencast |
| `Mod+Alt+Backspace`      | Clear Dynamic Screencast    |
| `Mod+TouchpadScrollDown` | Volume -2%                  |
| `Mod+TouchpadScrollUp`   | Volume +2%                  |
| `Mod+Shift+P`            | Power Off Monitors          |
 
