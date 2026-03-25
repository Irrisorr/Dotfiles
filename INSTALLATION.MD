# Installation Scripts Documentation

This document describes the structure and functions of the installation scripts located in the `install_scripts` directory. The scripts are executed in a specific chronological order and rely on multiple helper functions to build an interactive terminal UI (TUI) for the installation process.

## Overview of Actions

The installation process is divided into main actions (`main.sh`) and post-installation steps (`post_install.sh`). Here is a high-level summary of what gets configured natively during these processes:

### Main Installation (`main.sh`)
* **Core System Setup:** 
  * Performing system updates via `pacman`.
  * Installing the `yay` AUR helper.
  * Enforcing Cyrillic font support (`cyr-sun16`) for Arch Linux TTY consoles.
  * Translating and migrating default Russian XDG user directories (e.g., *Рабочий стол*) into English (*Desktop*).
* **Environment & Window Managers:**
  * Installing the user-selected Window Manager (Hyprland or Niri).
  * **Hyprland ecosystem**: 
    - Symlinking `hyprland` config directory, 
    - `hyprpm` configuration, 
    - `hyprlock` configuration, 
    - `nwg-displays` configuration for Python paths, 
    - `hyprpaper` configuration, 
    - injecting a custom wallpaper changer desktop shortcut.
  * **Niri ecosystem**: 
    - Symlinking `niri` config directory, 
    - `DankMaterialShell` configuration, 
    - `hyprlock` configuration.
* **App Configurations (Dotfile Symlinks):** Configs are generated and linked out-of-the-box for: 
  - **Fastfetch**
  - **Fish**
  - **Git** (U need to change username and email to yours in main.sh at the "#== Git Configuration" section).
  - **Kitty**
  - **Rofi**
  - **SDDM** (applying custom corners theme), 
  - **Spicetify**
  - **Thunar** (Custom Actions UCA), 
  - **Wlogout**
  - **Wofi**
* **System Tweaks & Daemons:**
  * Modifying GTK properties to remove standard window control buttons.
  * Enabling Bluetooth services and invoking Polkit authentication agents (GNOME/MATE).
  * Appending `enableWaylandShare=true` conditionally for **Zoom**.
  * Enrolling local fingerprint authentication via `fprintd`.
  * Removing legacy `.bak` directories recursively from `~/.config/`.

### Post-Installation (`post_install.sh`)
These actions handle auxiliary program binaries executed completely independent of the main TUI framework:
* **iMe Desktop:** Automates parsing your `Downloads` directory for the `iMe*.tar.xz` tarball, extracting it natively into `~/Downloads/apps/` and launching it briefly just to generate its generic `.desktop` file.
* **RustDesk:** Downloads and natively installs RustDesk v1.3.7 from its direct GitHub Release `.zst` target.
* **Hyprland Plugins:** Pushes the `virtcode/hypr-dynamic-cursors` plugin straight into `hyprpm`.
* **GitHub CLI:** Invokes `gh auth login` requiring explicit user browser validation.

## 1. `install.sh` (Entry Point)
This is the main executable script that starts the installation journey.
It does not contain any functions natively, but rather imports `functions.sh` and runs an infinite loop showing the first and second level menus until the user decides to safely exit.
```bash
# Example from install.sh
while true; do
  menu_first_level
  menu_second_level
  # Exits if user selects the exit option
  if [ $? -ne 3 ]; then
    break
  fi
done
```

## 2. `main.sh` (Action Database)
This file acts as a database of installation steps, maintaining a clean separation of data and logic. It is dynamically parsed by `functions.sh` to construct the interactive menus.
It utilizes custom bash comment syntax:
* **`#= `**: Defines a first-level action (e.g., `#= Update system`). These appear in the main, top-level installation menu.
* **`#== `**: Defines a second-level action (e.g., `#== Kitty Configuration`). These appear in the application configuration menu.

The bash code immediately following these text markers is dynamically extracted via `awk` and executed when the user selects the corresponding menu item.

## 3. `functions.sh` (Core Logic)
This file dictates the core logical behavior of the installation process. It handles menu rendering, reads package selections from files, parses `main.sh`, and creates execution subshells.

### Menu & Parsing Functions
* **`menu_first_level()`**: Renders the first-level actions menu using `gum` (or native fallback).
* **`menu_second_level()`**: Renders the second-level actions menu. It conditionally lists applications **only if** they are currently installed in the system environment.
* **`get_first_level_actions()`**: Extracts all first-level actions from `main.sh`.
* **`get_second_level_actions()`**: Extracts all second-level actions from `main.sh`.
* **`get_command_check()`**: Extracts the bash command check string (e.g., `if command -v <cmd>`) that exists right after a second-level action. It prevents the script from offering configuration for non-existent apps.
  * **Example usage:** `local cmd=$(get_command_check "Kitty Configuration")`
* **`execute_action_from_file()`**: Finds the corresponding bash code logic for a chosen action and executes it directly, tracking the final result (`✓` or `✗`).
  * **Arguments:** `$1` - Name of the action, `$2` - Level (1 or 2).
  * **Example usage:** `execute_action_from_file "Update system" "1"`
* **`get_action_code_by_level()`**: An awk-based parser that fetches the exact block of raw string code bounded by a specific action name.
  * **Arguments:** `$1` - Name of the action, `$2` - Level (1 or 2).
  * **Example usage:** `local code=$(get_action_code_by_level "Update system" "1")`

### Package Installation Functions
* **`package_category_selection()`**: Initiates the interactive TUI menu allowing users to select package categories (such as Terminal, Audio, etc.).
* **`get_all_categories()`**: Parses `packages.txt` and returns all the category section names.
* **`start_package_installation()`**: Collects all selected packages stored across all categories, asks for final user confirmation, and uses `yay` to install them in-bulk.
* **`select_packages_for_category()`**: Opens the nested interactive menu logic allowing granular toggling of specific packages strictly inside a designated category.
  * **Arguments:** `$1` - Category exact name.
  * **Example usage:** `select_packages_for_category "Terminal"`
* **`get_packages_from_category()`**: Collects the raw list of all installable packages registered inside a specific category block inside `packages.txt`.
  * **Arguments:** `$1` - Category exact name.
  * **Example usage:** `local app_list=$(get_packages_from_category "Browsers")`

### Helper Execution Functions
* **`execute_script()`**: Executes a raw terminal command string and securely triggers `check_success` to verify its successful conclusion.
  * **Arguments:** `$@` - Code string.
  * **Example usage:** `execute_script yay -S --noconfirm git neovim`
* **`execute_command()`**: Submits a user consent prompt before executing a potentially destructive or modifying script block inside an encapsulated `bash -c` subshell.
  * **Arguments:** `$1` - Prompt contextual message string, `$2` - Code string to execute.
  * **Example usage:** `execute_command "Update user directories" "xdg-user-dirs-update"`
* **`create_symlink()`**: Safely provisions symlinks. If the destination is already an existing symlink, it removes it cleanly. If it's a real file or folder, it modifies it with a `.bak` extension before linking.
  * **Arguments:** `$1` - Source absolute file path, `$2` - Target absolute config path.
  * **Example usage:** `create_symlink $HOME/Dotfiles/kitty $HOME/.config/kitty`
* **`system_update()`**: Wraps an execution of Arch's `sudo pacman -Syu --noconfirm`.
* **`install_yay()`**: Injects the AUR helper `yay` by cloning via Git and executing `makepkg` directly.
* **`set_ru_font()`**: Patches `/etc/vconsole.conf` forcing `cyr-sun16` fonts for rendering Cyrillic character support locally in basic terminals (TTY).
* **`convert_xdg_dirs_to_english()`**: Evaluates your home directories (`Рабочий стол`, `Загрузки`). If found, re-generates new default English counterparts (`Desktop`, `Downloads`) and performs secure migrating of local documents.

## 4. `gum_functions.sh` (TUI Wrappers)
This file operates as the visual UI wrapper around the `gum` styling utility to generate aesthetic and interactive lists. Should `gum` fail to install or be locally missing, this file cleanly substitutes with traditional bash built-ins (like `read` and `echo`).

* **`gum_choose_wrapper()`**: A versatile and heavily customized wrapper scaling on native `gum choose`. It manages argument manipulation allowing custom heights, native multi-selection, and defaulting to pre-selected toggles efficiently.
  * **Arguments:** Iteration cases `--multi`, `--height H`, `--selected ITEM`, followed immediately by options natively readable via map formatting.
  * **Example (Single):** `choice=$(gum_choose_wrapper --height 20 "${options[@]}")`
  * **Example (Multi with previously toggled keys):** `selected=$(gum_choose_wrapper --multi --height 15 --selected "git" --selected "vim" "${options[@]}")`
* **`choose_action()`**: Standard single-use prompt interface.
  * **Arguments:** Array of text parameters options.
  * **Example usage:** `window_manager=$(choose_action hyprland niri)`
* **`choose_action_no_limit()`**: Standard multi-checkbox use prompt. Select packages individually toggling spacebar prior to executing Enter.
  * **Arguments:** Array of text parameters options.
  * **Example usage:** `choice=$(choose_action_no_limit "${options[@]}")`
* **`confirm_action()`**: Intercepts actions requiring explicit permissions. Pushes a native Yes/No context prompt. Relays `0` on successful 'Yes', `1` for denied 'No'.
  * **Arguments:** `$1` - Context notification string.
  * **Example usage:** 
    ```bash
    if confirm_action "install window manager"; then
      # executes internal response...
    fi
    ```
* **`check_success()`**: Checks internal last system exit code variable (`$?`). Yields styled green responses on `0` exits or stops tracking throwing red outputs.
  * **Arguments:** `$1` - Informational contextual message identifying the recently handled execution.
  * **Example usage:** `check_success "Created symlink from $source to $target"`
* **`print_success_message()`**: Evaluates and pushes out styled text highlighting in neon-green and checkmarks explicitly informing local users.
  * **Arguments:** `$1` - Direct string notification log.
  * **Example usage:** `print_success_message "All packages installed successfully!"`
* **`print_error_message()`**: Evaluates and pushes out styled text highlighting in neon-red and crossbars expressly notifying user failures.
  * **Arguments:** `$1` - Direct string notification log.
  * **Example usage:** `print_error_message "No packages selected!"`
* **`print_styled_message()`**: Produces large styled neon-pink title blocks serving as aesthetic banners denoting stage transitions.
  * **Arguments:** `$1` - Direct string notification log.
  * **Example usage:** `print_styled_message "Configuring hyprland and apps/plugins for it"`

## 5. `post_install.sh` (Post-Installation)
An auxiliary secondary payload file. It acts and launches completely separately after managing to execute the entire primary install logic. It borrows core functionalities natively from `functions.sh` but proceeds deterministically linearly.

## 6. `packages.txt` (Package Resources)
Serving exclusively as the primary raw document lookup repository. Sets of installable programs are blocked linearly delimited via generic bash hashes `# Name`, followed explicitly by clean one-liner executable package titles via `yay`.
