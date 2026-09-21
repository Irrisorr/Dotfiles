# Scripts Documentation

The two entry points (`install.sh`, `post_install.sh`) live at the repo root.
Everything else lives under `scripts/`, split so reusable helpers, the installer
data, the everyday aliases, and the backup tool stay separate.

```
Dotfiles/
  install.sh         # installer entry point  (./install.sh)
  post_install.sh    # runs once after reboot  (./post_install.sh)
  scripts/
    lib/
      common.sh      # path constants + sources lib/  (source this everywhere)
      gum.sh         # gum / fallback UI wrappers
      helpers.sh     # universal menu(), execute_*, create_symlink, package engine, system_update
    install/
      packages.txt   # package inventory by category
      system/        # system-level config functions
      apps/          # per-app config functions (one file per app)
    functions/       # shell-alias functions shown in the `asd` menu (incl. alias_menu.sh)
      sync/          # an alias that needs its own folder
        sync_private.sh  # back up live/sensitive files into the private repo
        sync_map.json    # dest -> [sources] mapping
```

## `common.sh` (constants + includes)

Source it at the top of any script:

```bash
. "$HOME/Dotfiles/scripts/lib/common.sh"
```

It exports the path constants — `DOTFILES_DIR`, `PRIVATE_DIR`, `SCRIPTS_DIR`,
`LIB_DIR`, `INSTALL_DIR`, `SYSTEM_DIR`, `APPS_DIR`, `FUNCTIONS_DIR`,
`CONFIG_DIR` — then sources `lib/gum.sh` and `lib/helpers.sh`, so one line gives
you every constant and helper. It is guarded, so re-sourcing it in the same
shell is a no-op.

## `lib/` (reusable helpers)

* **`gum.sh`** — UI wrappers around `gum` (`gum_choose_wrapper`, `confirm_action`,
  `print_success_message`, `print_error_message`, `print_styled_message`,
  `check_success`). Falls back to plain bash (`read`/`echo`) if `gum` is absent.
* **`helpers.sh`** — generic, no app-specific code:
  * `menu` — the **universal menu** (see below). One function powers every menu.
  * Execution: `execute_script`, `execute_command`, `create_symlink`.
  * Package engine: `package_category_selection`, `get_all_categories`,
    `get_packages_from_category`, `select_packages_for_category`,
    `start_package_installation`.
  * `system_update` — reused by both the installer and `post_install.sh`.
  * `reload_shell_prompt` — offers to `exec fish` so env edits to `config.fish`
    take effect (used by `set_env` / `delete_env`).

  One-shot, configuration-like logic does **not** live here — it sits where it is
  used (the cyrillic font and yay bootstrap are functions in
  `install/main.sh`; the per-app config is a function in its `install/*/<name>.sh` file).

## The universal `menu`

Every menu in the repo is one function in `lib/helpers.sh`:

```bash
menu <back_label> <entry>...
#   entry = "Label|function"            run `function` when picked
#           "Label|function|guard_cmd"  same, but hidden unless guard_cmd exists
```

* **Custom labels** — the label shown in the terminal is decoupled from the
  function name (`"Yay/Pacman commands|yay_commands"` shows `Yay/Pacman commands`).
* **Guards** — an optional third field hides the entry unless that command is
  installed (`"Zen Browser|configure_zen|zen-browser"`). Full paths work too.
* **Nested menus** — a function passed to `menu` may itself call `menu` again;
  that becomes a submenu with its own back button. When the submenu returns, you
  land back in the parent. No exit-code plumbing — `return` from the loop is all
  it takes. `config_menu` and `yay_commands` are exactly this.
* **Back / status** — the `<back_label>` entry (`"⬅️ Back"`, `"🚀 Finish"`) is
  always appended last; picking it returns. Each function's ✓/✗ is tracked and
  shown next to its label on the next pass.

## `install.sh` (root) + `install/main.sh`

The work is split so that **`install.sh` holds only the menus** and
**`install/main.sh` is the engine** — adding a configuration means touching
`install.sh` alone, never the engine.

`install/main.sh` (the engine) is `source`d by `install.sh`. It sources
`common.sh`, sources every config function (`system/*.sh` then `apps/*.sh`),
defines the core-step functions (`install_yay`, `set_cyrillic_font`,
`install_window_manager`), and defines `run_final_steps`. It runs no menu and
nothing top-level on its own.

`install.sh` (the entry point — `./install.sh`) sources the engine, then is just
the two menus and the final call:

```bash
. "$HOME/Dotfiles/scripts/install/main.sh"   # engine: everything except the menus

config_menu() {                              # the configuration submenu
  menu "⬅ Back to main menu" \
    "Niri ecosystem|configure_niri|niri" \
    ...one line per config function...
}

menu "🚀 Finish & continue" \                # the first menu
  "Update system|system_update" \
  "Install yay|install_yay" \
  "Set cyrillic console font|set_cyrillic_font" \
  "Install packages|package_category_selection" \
  "Install Window Manager|install_window_manager" \
  "App / system configuration|config_menu"

run_final_steps                              # defined in the engine
```

* **First menu**: core steps plus `config_menu`. `system_update` lives in
  `lib/helpers.sh`; `install_yay`, `set_cyrillic_font`, `install_window_manager`
  are in the engine.
* **`config_menu`**: a function that calls `menu` again with one entry per config
  function (system first, then apps), each with a guard. Its back button returns
  to the first menu — that's the nesting, no special casing. **This is the one
  place to edit when adding/removing a configuration.**
* **`run_final_steps`** (in the engine, called by `install.sh` after the menus):
  delete leftover `.bak` dirs, install the one-shot post-install fish hook (runs
  `~/Dotfiles/post_install.sh` on the next interactive shell, then deletes
  itself), then ask to reboot. Either way it prints a "configuration complete"
  message — reboot-now warns it's seconds away and that post-install runs on the
  next terminal; no-reboot says a reboot is recommended and post-install will run
  after it.

### How a config file works

Each file in `install/system/` and `install/apps/` defines one or more
`configure_*` functions — a normal sourced shell function, no markers, no eval:

```bash
#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: kitty
configure_kitty() {
  execute_command "Configure kitty" "mkdir -p $HOME/.config/kitty && create_symlink $HOME/Dotfiles/kitty $HOME/.config/kitty"
}
```

The engine (`main.sh`) sources every such file, so the functions exist; then
`config_menu` (in `install.sh`) lists them with a label and (usually) a guard.
The old top-level `if command -v` check is now the menu's guard field — the
function body assumes its command is present.

**Adding a config step:** write `configure_<name>()` in a file under
`system/` or `apps/` (the engine globs the folder and sources it automatically),
then add one `"Label|configure_<name>|<guard>"` line to `config_menu` in
`install.sh`. The engine is never touched.

## `post_install.sh` (root entry point)

Runs once after the reboot, triggered by the fish hook in
`~/.config/fish/conf.d/` (which deletes itself after firing). Executed linearly

## `packages.txt`

Categories delimited by `# Name` headers, each followed by one package per line,
installed via `yay` by the package engine.

## `functions/` (aliases + `asd` menu)

One file per alias, named after the function it defines. Each file sources
`common.sh`, defines its function, and ends with a dispatcher that runs the
function only when the file is executed directly (not when sourced):

```bash
#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Rain animation
terminal_rain() { terminal-rain "$@"; }

[ "${BASH_SOURCE[0]}" = "$0" ] && terminal_rain "$@"
```

`scripts/functions/alias_menu.sh` (the `asd` menu) sources every `*.sh` under
`functions/` **recursively** (so the functions exist), then lists them in one
`menu` call with labels and guards. Recursion means an alias that needs its own
folder — assets, a JSON config, etc. — just gets a subfolder (e.g.
`functions/sync/`); only its `*.sh` is sourced, anything else is ignored:

```bash
menu "🚪 Exit" \
  "Set env var|set_env" \
  "Rain animation|terminal_rain|terminal-rain" \
  "Yay/Pacman commands|yay_commands"
```

Fish wrappers in `fish/functions/` just run the file and pass arguments:
`bash $HOME/Dotfiles/scripts/functions/terminal_rain.sh $argv`.

`yay_pacman.sh` defines `update_system`, `upgrade_system`, and a `yay_commands`
function that opens a submenu (it calls `menu` again). Having more than one entry
point, its dispatcher is generic (`… && "$@"`) so the caller — a fish wrapper or
the asd menu — names which function to run.

**Adding an alias:** drop a `<name>.sh` file here (or a subfolder with one, if it
needs its own assets) defining its function, then add a `"Label|<func>[|guard]"`
line to the `menu` call in `scripts/functions/alias_menu.sh`.

### `set-env` / `delete-env` and shell restart

The fish wrappers are one-liners — they just run the bash script. All the logic,
including the restart, lives in `set_env.sh` / `delete_env.sh`: after a
successful change they call `reload_shell_prompt` (in `lib/helpers.sh`), which
offers to `exec fish`. A subshell can't mutate the parent shell's env, so
replacing it with a fresh fish is how the change to `config.fish` is applied.

## `functions/sync/` (private-files backup)

An alias that lives in its own folder. `sync_map.json` (next to the script) is an
array of objects. Two kinds of entry:

```json
[
  { "dest": "~/Dotfiles-private/zen-browser",
    "sources": ["~/.config/zen/*release*/zen-sessions.jsonlz4", "..."] },

  { "dest": "~/Dotfiles-private/zen-browser",
    "sqlite": "~/.config/zen/*release*/places.sqlite",
    "table": "zen_bookmarks_workspaces" }
]
```

* **file group** (`sources`) — copied with `cp -rf`. Sources may be **files or
  folders**; `~` expands to home and `*` globs are supported, so a changing
  profile-folder name still matches.
* **sqlite** (`sqlite` + `table`) — dumps a single table to `<dest>/<table>.sql`
  (e.g. `zen_bookmarks_workspaces`) instead of the whole database. The dump opens
  the DB with `file:<db>?immutable=1` (read-only, no locking), so it works even
  while Zen is running — no "database is locked" error.

Run it as `sync-private` or from the `asd` menu. It checks its dependencies and
tells you which package to install if one is missing (`jq` is required; `sqlite`
is required only when the map has table entries — those are skipped otherwise).
Before overwriting files that already exist in a dest, you get one
gum selection with **every conflicting file pre-selected** (= will be
overwritten) — unselect the ones you want to keep. An optional `"comment"` field
is ignored.

**Restore** is handled by `restore_private_zen` in `install/apps/zen.sh` (reused
by both `configure_zen` and `post_install.sh`): it copies the live files back
into the profile and imports each `*.sql` dump into the profile's `places.sqlite`
(dropping the table first, so sibling tables like history/bookmarks are
untouched).
