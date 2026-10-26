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

- After it reboot your device and open new terminal, there will be a hook that will run `post_install.sh` automatically. If something went wrong, you can run it manually:
```
cd Dotfiles
./post_install.sh
```

### On Ubuntu

- Same steps, same menus — nothing to choose by hand. Differences the installer handles by itself:
    - **niri**, `xwayland-satellite` and **dms** come from the DankMaterialShell author's PPAs (`ppa:avengemedia/danklinux`, `ppa:avengemedia/dms`) — they are not in the Ubuntu repos
    - apps that are only in the AUR (Zen, VS Code, Obsidian, Discord, Spotify, ...) are installed from **Flathub** — and get a command with the usual name in `/usr/local/bin` (`zen-browser`, `code`, `spotify`, ...), so niri keybinds and the config menu work the same as on Arch
    - `clipse` (release binary), JetBrains Mono Nerd Font (official nerd-fonts release) and FreeOffice (SoftMaker's apt repo) have their own installers in `scripts/install/system/sources.sh`; re-run the package step to update clipse and the font
    - SDDM replaces GDM as the login screen (the **SDDM** config step switches it; it prints the command to switch back)
- Known differences:
    - 12 packages have no Ubuntu source and are skipped (the installer names them before installing): `anyrun`, `walker`, `gowall`, `hyprswitch`, `hyprshot`, `arronax`, `vimix-gtk-themes`, `waydroid`, `spicetify-cli`, `terminal-rain-lightning`, `logmein-hamachi`, `ags-hyprpanel-git`
    - fingerprint driver (`libfprint-2-tod1-goodix-v2`, 27c6:550a) is installed from the same `.deb` the AUR package repackages — it doesn't update by itself
    - `iMe`, `claude-code` and `claude-desktop` have no Ubuntu source yet — the installer reports them as `missing:` and installs everything else

### Adding a package

- One line in `scripts/install/packages.txt` under its category — it's installed on both distros. If on Ubuntu the package has another name or comes from somewhere else, add a tail (full format in [INSTALLATION.MD](INSTALLATION.MD#packagestxt)):
```
neovim
sqlite                 ubuntu:apt=sqlite3 (need for sync private dotfiles)
zen-browser-bin        ubuntu:flatpak=app.zen_browser.zen (based on firefox)
logmein-hamachi        ubuntu:skip (VPN service | Ubuntu: .deb at vpn.net, unversioned URL)
```

# Syncing between machines

- Configs are symlinks into `~/Dotfiles`, so the repo **is** the config: change something on one machine, commit & push, then `git pull` on the other one — done
- WM configs never hold distro-specific paths (polkit agent, portals go through `scripts/wrappers/`), so the same niri/hyprland config works on both
- Things that are per machine and need care:
    - monitors (`niri/conf/output.kdl`, `open-on-output` in `workspaces.kdl`) — u can list the monitors of both machines in the same file, niri ignores outputs that aren't connected
    - `fish/fish_variables` is rewritten by fish itself (and depends on its version) — expect it to show up in `git status`
    - `set-env` / `set-java` write into `fish/config.fish`, which is in the repo — f.e. `JAVA_HOME` is `/usr/lib/jvm/java-23-openjdk` on Arch but `/usr/lib/jvm/java-25-openjdk-amd64` on Ubuntu, so don't commit machine-specific values

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

### Layout (`niri/config.kdl`)

- Small gaps (10 px) between window's edges and no background color (transparent)
- Never centered a window when changing focus between windows and always center when only 1 window is on a worskspace
- Default window (column) width is 100%
- Presets for actions like `switch-preset-column-width (Mod+R)` and `switch-preset-window-height (Mod+Shift+R)` are 0.5 (50%) and 1.0 (100%)
- Border (with gradient) around active window
- Shadows below windows (u can see them )

### Workspace (`niri/conf/workspaces.kdl`)

- There is 4 named workspaces: **_media**, **browser**, **ide** and **notes**
- They r opened on my specific monitor, so u had to change the name of monitor to urs (at `open-on-output "<here ur monitor name>"`)
- Workspaces are sorted **alphabetically**, so i had to add `_` in **_media** if i wanted this worspace to be the first

### Window/Layer rules (`niri/conf/rules.kdl`)

- **Corner radius** for all windows is 18
- **Indicate screencasted windows** with red colors
- Some apps that **blocked from screencasting** (u can add ur apps if u want)
- Apps that should open on the **_media / browser / ide / notes** workspace
- **Picture in picture** always floating
- **Clipse** always opens floating and small size
- **Kitty** always opens at 50% (0.5) window size proportion
- **Obsidian** has scroll-factor 0.2
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
- **dms** - panel bar
- **swaybg** - wallpaper tool
- **syncthing** - local server for synchronize folders between laptop and phone or another devices in real time
- **clipse** - clipboard app
- kill all **xdg-desktop-portals** for rerun while startup to avoid unexpected problems during the session

### Environment (`niri/conf/envs.kdl`)

- `ELECTRON_OZONE_PLATFORM_HINT "auto"` - Force Electron applications (like VS Code, Discord, Obsidian) to automatically detect and use the native Wayland display server on Linux
- `QT_QPA_PLATFORM "wayland"` - Force Qt-based applications (like KDE apps, VLC, OBS) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `ELECTRON_ENABLE_WAYLAND "1"` - Forces Electron applications to run natively on the Wayland display protocol 
- `MOZ_ENABLE_WAYLAND "1"` - Force Mozilla applications (like Firefox) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `GDK_BACKEND "wayland"` - Force GTK applications (like Gnome apps) to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `OBSIDIAN_USE_WAYLAND "1"` - Force Obsidian to use the native Wayland display protocol instead of running through the XWayland compatibility layer
- `QT_QPA_PLATFORMTHEME "gtk3"` - Force Qt applications to use the GTK3 platform theme for better integration with the desktop environment

### SDDM (`sddm/`)

- Theme **corners** — based on [aczw/sddm-theme-corners](https://github.com/aczw/sddm-theme-corners), ported to **Qt6** (upstream is Qt5-only), so the same theme works on Arch and Ubuntu (Ubuntu's sddm has only the Qt6 greeter)
- Greeter runs on **Wayland** (`DisplayServer=wayland`, `weston --shell=kiosk` as its compositor) — no X server needed
- Preview the theme in a window without logging out:
```
sddm-greeter-qt6 --test-mode --theme ~/Dotfiles/sddm/corners
```
- `configure_sddm` copies the theme and `default.conf` into the system dirs, so after editing them re-run the **SDDM** step in `./install.sh`

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
  scripts/
    lib/             # reusable helpers (no app-specific logic)
      common.sh      # path constants + sources lib/  (source this everywhere)
      distro.sh      # distro detection + package managers (pacman/yay/apt, flatpak, snap, PPAs)
      paths.sh       # paths that differ between distros (polkit, portals, sddm, fish, ...)
      gum.sh         # gum bootstrap + UI wrappers
      helpers.sh     # universal menu(), execute_*, create_symlink, package engine, system_update
    wrappers/        # launchers called from WM configs, resolve distro-specific paths (polkit, portals)
    install/
      main.sh        # installer ENGINE: sourcing + core-step functions + run_final_steps (no menus)
      packages.txt   # one line per package, works for both distros
      system/        # system-level config functions: niri, hyprland, sddm, fingerprint, gtk/bluetooth/polkit, xdg, flatpak, sources.sh (custom installers)
      apps/          # per-app config functions: zen, kitty, fish, thunar, rofi, ...  (ONE file per app)
    functions/       # everyday shell aliases + alias_menu.sh (the `asd` menu)
      sync/          # private-files backup tool: sync_private.sh + sync_map.json (see below)
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
    - `sync-private` - back up private/sensitive files into `~/Dotfiles-private` (requires `jq`; see below)
    - 'System packages' - update / upgrade on both distros:
        - `update` - sync package lists (`yay -Sy` / `apt update`)
        - `upgrade` - install all updates: `yay -Syu` / `apt full-upgrade`, plus `flatpak update` (asks before installing, like running them by hand)

#### Private/sensitive files backup (`scripts/functions/sync/`)

- Sensitive profile data (Zen sessions, etc.) lives in a separate **private** repo (`~/Dotfiles-private`), not here
- `scripts/functions/sync/sync_map.json` is an array of two kinds of entry:
    - **file group**: `{ "dest": "~/Dotfiles-private/zen-browser", "sources": ["fileA", "folderB", ...] }` — files or folders (copied recursively), `~` and `*` globs supported
    - **sqlite table**: `{ "dest": "...", "sqlite": "~/.../places.sqlite", "table": "zen_bookmarks_workspaces" }` — backs up just one table (dumped to `<table>.sql`) instead of the whole DB
    - an optional `"comment"` field per object is ignored
- Run `sync-private` (or pick it from the `asd` menu) to sync into the private repo, then commit/push it (needs `jq`; sqlite entries need `sqlite3`). Files that already exist in a dest are shown in one gum selection, all pre-selected — **unselect** the ones you want to keep instead of overwriting
- On a fresh install `post_install.sh` clones (or `git pull`s) `Dotfiles-private` and — with your confirmation — restores those files back into the Zen profile: live files are **copied** (not symlinked, since the browser rewrites them at runtime) and each `*.sql` table dump is imported into `places.sqlite`. The default `configure_zen` step does the same restore if the private repo is already present


# Key Bindings

### Apps

| Keybinding    | App                       |
| :---          | :---                      |
| `Mod+Return`  | Kitty (Terminal)          |
| `Mod+B`       | Zen Browser (Browser)     |
| `Mod+E`       | Thunar (File Explorer)    |
| `Mod+C`       | VSCode                    |
| `Mod+N`       | Obsidian (Notes)          |
| `Mod+M`       | Spotify (Music)           |
| `Mod+Shift+T` | iMe (Telegram client)     |
| `Mod+D`       | Vesktop (Discord client)  |
| `Alt+Space`   | Rofi (App Launcher)       |
| `Ctrl+Space`  | Rofi (Window Manager)     |
| `Mod+V`       | Clipse (Clipboard)        |
| `Mod+L`       | Hyprlock (Lock Screen)    |
| `Mod+Shift+L` | Wlogout (Logout Manager)  |

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
| `Mod+Shift+/`            | Hotkey Overlay              |
| `Mod+Shift+S`            | Screenshot (Ctrl+C to copy) |
| `Mod+Shift+End`          | Screenshot Screen           |
| `Mod+End`                | Screenshot Window           |
| `Mod+Backspace`          | Pick Window for Screencast  |
| `Mod+Shift+Backspace`    | Pick Monitor for Screencast |
| `Mod+Alt+Backspace`      | Clear Dynamic Screencast    |
| `Mod+TouchpadScrollDown` | Volume -0.02                |
| `Mod+TouchpadScrollUp`   | Volume +0.02                |
| `XF86AudioRaiseVolume`   | Volume +0.1                 |
| `XF86AudioLowerVolume`   | Volume -0.1                 |
| `XF86MonBrightnessUp`    | Brightness +5%              |
| `XF86MonBrightnessDown`  | Brightness -5%              |
| `XF86AudioMute`          | Toggle Mute                 |
| `XF86AudioMicMute`       | Toggle Mic Mute             |
| `Mod+Shift+P`            | Power Off Monitors          |
 
