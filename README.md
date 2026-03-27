# My Dotfiles for niri WM

# Installation with config/packages choices

- Type in terminal next commands (**IMPORTANT**: clone repo to home directory):
```
cd ~
git clone https://github.com/Irrisorr/Dotfiles
cd Dotfiles/install_scripts
./install
```

- After it reboot your device and type next in terminal:
```
cd Dotfiles/install_scripts
./post_install
```

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

### Window rules (`niri/conf/rules.kdl`)

- **Corner radius** for all windows is 18
- **Indicate screencasted windows** with red colors
- Some apps that **blocked from screencasting** (u can add ur apps if u want)
- Apps that should open on the **_media / browser / ide / notes** workspace
- **Picture in picture** always floating
- **Clipse** always opens floating and small size
- **Kitty** always opens at 50% (0.5) window size proportion
- **Obsidian** has scroll-factor 0.2

### Animations (`niri/conf/animations.kdl`)

- Default niri animations

### Autostart (`niri/conf/autostart.kdl`)

- **wl-clipboard** for clipboard history
- **polkit-mate** for authenticate apps
- **dms** - panel bar
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

### Aliases (`fish/functions/*`)

> Right now there is only **fish** shell aliases, but u can add shell scripts for other shells too using their functions

- All aliases is shell scripts in `scripts/scripts.sh` file 
- You can run aliases by it's name in terminal (see below)
- You can run menu with all aliases by typing `asd` in terminal and choose needed script
- Comments `#= <alias_name>` above functions for 1st level menu 
- Comments `##= <alias_name>` above functions for 2nd level menu (like `system update` under `Yay/Pacman commands` choice in 1st level menu)

#### Scripts (just type name of script in terminal or use `asd` menu)

- `asd` - Menu with all useful scripts by choosing from list:
    - `set-env <var_name> <var_value>` - Set a new environment variable
    - `delete-env <var_name>` - Delete an environment variable
    - `set-java` - Set Java environment variable with selection from existing java versions (check `/usr/lib/jvm/`)
    - `rain` - Rain animation (if installed `terminal-rain` package)
    - `rain-float` - Rain animation in mini floating window (if installed `terminal-rain` package)
    - `vim` - open **nvim** on **ide** workspace and maximize window (if installed `neovim` package)
    - 'Yay/Pacman commands' - menu with useful yay/pacman commands:
        - `update` - update system (`yay -Sy`)
        - `upgrade` - upgrade system (`yay -Syu`)


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
 
