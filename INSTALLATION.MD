# Scripts Documentation

The two entry points (`install.sh`, `post_install.sh`) live at the repo root.
Everything else lives under `scripts/`, split so reusable helpers, the installer
data, the everyday aliases, and the backup tool stay separate.

The same scripts run on **Arch** (and its derivatives: CachyOS, EndeavourOS) and
on **Debian/Ubuntu**. The distro is detected at startup; everything that differs
between them goes through `lib/distro.sh` (package managers), `lib/paths.sh`
(file locations) and the per-distro tails in `packages.txt` — no other script
branches on the distro.

```
Dotfiles/
  install.sh         # installer entry point  (./install.sh)
  post_install.sh    # runs once after reboot  (./post_install.sh)
  scripts/
    lib/
      common.sh      # path constants + sources lib/  (source this everywhere)
      distro.sh      # distro detection + package-manager abstraction (pkg_*, flatpak, snap, url, add_repo)
      paths.sh       # resolvers for paths that differ between distros (polkit, portals, sddm, fish, python, console font)
      gum.sh         # gum bootstrap + UI wrappers
      helpers.sh     # universal menu(), execute_*, create_symlink, package engine, system_update
    wrappers/        # tiny launchers called from WM configs (polkit agent, xdg portals)
    install/
      main.sh        # installer engine: sourcing + core steps + run_final_steps (no menus)
      packages.txt   # package inventory by category, one line per package for both distros
      system/        # system-level config functions (+ sources.sh: custom package installers)
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
`CONFIG_DIR` — then sources `lib/distro.sh`, `lib/paths.sh`, `lib/gum.sh` and
`lib/helpers.sh` (in that order: the gum bootstrap needs `pkg_install`), so one
line gives you every constant and helper. It is guarded, so re-sourcing it in
the same shell is a no-op.

## `lib/` (reusable helpers)

* **`distro.sh`** — reads `/etc/os-release` (`ID`, then `ID_LIKE`) and sets:
  * `DISTRO` — the raw id (`cachyos`, `ubuntu`, ...)
  * `DISTRO_FAMILY` — `arch` | `debian` | `unknown`. **Branch on this**, not on
    `DISTRO`; `is_arch` / `is_debian` are the shorthands.
  * `PKG_MGR` — `yay` (if installed) or `pacman` on Arch, `apt` on Debian.

  Package functions, one per operation, so no caller ever writes `pacman` or
  `apt` itself: `pkg_install` (`--needed` on Arch), `pkg_sync`, `pkg_upgrade`
  (also runs `flatpak update` when flatpak is present; `-i` keeps every
  manager's prompts — the `upgrade` alias uses it, the installer doesn't), `pkg_installed`,
  `pkg_available`, `pkg_install_hint`. Other backends: `ensure_flatpak` /
  `flatpak_install` (Flathub, `--user`), `snap_install`, `url_install` (download
  a `.deb` / `.pkg.tar.zst` and install it with the native manager, so
  dependencies resolve), `add_repo` (a PPA on Debian, no-op on Arch).
  Standalone — does not source `gum.sh` / `helpers.sh`.
* **`paths.sh`** — resolvers for files that live in different places per distro.
  Each one is a **candidate list, first existing path wins**, Arch's path listed
  first — not an `if is_arch`: `find_polkit_agent` (+ `has_polkit_gnome` /
  `has_polkit_mate` for menu guards), `find_portal_binary`, `sddm_confd_dir`,
  `sddm_themes_dir`, `fish_bin`, `ensure_login_shell` (adds the shell to
  `/etc/shells` before `chsh` — Ubuntu rejects it otherwise), `python_site_dir`,
  `set_console_font`. Standalone like `distro.sh`.
* **`gum.sh`** — UI wrappers around `gum` (`gum_choose_wrapper`, `confirm_action`,
  `print_success_message`, `print_error_message`, `print_styled_message`,
  `check_success`). Installs gum on first use: from the repos on Arch, from
  Charm's official apt repository on Ubuntu (apt has no gum; it asks first) —
  `add_charm_repo`, so gum then upgrades with `apt upgrade`.
  `menu` and the package picker **require** gum (`require_gum`); the small
  helpers fall back to plain bash (`read`/`echo`) without it.
  `DOTFILES_NO_GUM_BOOTSTRAP=1` sources it without installing anything.
* **`helpers.sh`** — generic, no app-specific code:
  * `menu` — the **universal menu** (see below). One function powers every menu.
  * Execution: `execute_script`, `execute_command`, `create_symlink`:
    * `execute_command "<message>" "<command>"` asks, then runs the command in
      a fresh bash with `common.sh` loaded. Returns **1** when you decline (no
      mark in the menu) and **2** when the command fails (✗ in the menu).
    * `create_symlink <source> <target>` — whatever was at `<target>` before (a
      real config from an earlier install) is moved to `<target>.bak`; if a
      `.bak` already exists, the new one gets `.bak.<date-time>`. A stale
      symlink is simply replaced. If `<target>` already resolves to `<source>`
      it does nothing ("Already linked") — this also protects files reached
      through a linked dir (`~/.config/hypr/x` when `~/.config/hypr` is itself
      a link into Dotfiles). It creates the parent dir, so callers must **not**
      `mkdir -p` the target itself — that would leave an empty `.bak`.
  * Package engine: `package_category_selection`, `get_all_categories`,
    `get_packages_from_category`, `select_packages_for_category`,
    `start_package_installation`, `install_packages` (the one entry point for
    installing anything from `packages.txt`).
  * `system_update` — reused by both the installer and `post_install.sh`.
  * `fish_apply` / `fish_quote` — hand a fish command back to the calling fish
    shell (used by `set_env` / `delete_env`).

  One-shot, configuration-like logic does **not** live here — it sits where it is
  used (the cyrillic font and yay bootstrap are functions in
  `install/main.sh`; the per-app config is a function in its `install/*/<name>.sh` file).

## The universal `menu`

Every menu in the repo is one function in `lib/helpers.sh`:

```bash
menu <back_label> <entry>...
#   entry = "Label|function"          run `function` when picked
#           "Label|function|guard"    same, but hidden unless the guard passes
```

* **Custom labels** — the label shown in the terminal is decoupled from the
  function name (`"System packages|package_commands"` shows `System packages`).
* **Guards** — an optional third field hides the entry unless it passes. Several
  tokens can be joined with `+`, and all of them must pass:
  * `<command>` — that command exists (`"Zen Browser|configure_zen|zen-browser"`);
    full paths work too
  * `distro:<id>` — matches `$DISTRO` or `$DISTRO_FAMILY`
    (`"Install yay|install_yay|distro:arch"`)
  * `test:<func>` — runs a shell function and uses its exit status
    (`"Start GNOME polkit agent|start_polkit_gnome|test:has_polkit_gnome"`) —
    for checks that are not a plain command, like a binary that lives at a
    different path per distro
* **Nested menus** — a function passed to `menu` may itself call `menu` again;
  that becomes a submenu with its own back button. When the submenu returns, you
  land back in the parent. No exit-code plumbing — `return` from the loop is all
  it takes. `config_menu` and `package_commands` are exactly this.
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
  menu "<─ Back to main menu" \
    "Niri ecosystem|configure_niri|niri" \
    ...one line per config function...
}

menu ">>> Finish & continue <<<" \          # the first menu
  "Update system|system_update" \
  "Install yay|install_yay|distro:arch" \
  "Set cyrillic console font|set_cyrillic_font" \
  "Install Window Manager|install_window_manager" \
  "Install packages|package_category_selection" \
  "App / system configuration|config_menu"

run_final_steps                              # defined in the engine
```

* **First menu**: core steps plus `config_menu`. `system_update` (runs
  `pkg_upgrade`) lives in `lib/helpers.sh`; `install_yay`, `set_cyrillic_font`,
  `install_window_manager` are in the engine. `Install yay` only shows on Arch.
  `install_window_manager` goes through `install_packages`, so on Ubuntu niri
  gets its PPA like any other package.
* **`config_menu`**: a function that calls `menu` again with one entry per config
  function (system first, then apps), each with a guard. Its back button returns
  to the first menu — that's the nesting, no special casing. **This is the one
  place to edit when adding/removing a configuration.**
* **`run_final_steps`** (in the engine, called by `install.sh` after the menus):
  list every backup `create_symlink` left in `~/.config` (`*.bak` and
  `*.bak.<date>`, dirs and files) and delete them all if you confirm — `find`
  does not follow symlinks, so nothing inside `~/Dotfiles` is touched through a
  linked config dir. Then install the one-shot post-install fish hook (runs
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
  execute_command "Configure kitty" "create_symlink $HOME/Dotfiles/kitty $HOME/.config/kitty"
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

Categories delimited by `# Name` headers. A header can carry a guard, in the
same syntax as `menu` — the category only shows in the picker when it passes:

```
# niri Ecosystem | niri
# Hypr Ecosystem | hyprland
```

Each header is followed by **one line per package — the same line serves both
distros**:

```
<canonical> [<distro>:<backend>[=<value>]]... [(description)]
```

`<canonical>` is the Arch name. With no tail the package is installed with the
native manager under that name on every distro. A tail is only needed when a
distro actually differs:

```
neovim
sqlite                 ubuntu:apt=sqlite3 (need for sync private dotfiles)
zen-browser-bin        ubuntu:flatpak=app.zen_browser.zen (based on firefox)
niri                   ubuntu:ppa=duxlabs/dux (the compositor itself)
dms-shell              ubuntu:ppa=duxlabs/dms ubuntu:apt=dms (panel bar)
clipse                 ubuntu:source=clipse (clipboard tui manager | Ubuntu: release binary, re-run to update)
logmein-hamachi        ubuntu:skip (VPN service | Ubuntu: .deb at vpn.net, unversioned URL)
```

`neovim` has the same name everywhere; `sqlite` is renamed on Ubuntu; Zen comes
from Flathub; niri and dms come from a PPA (dms under another name as well);
clipse is built by `install_source_clipse`; hamachi is not installed on Ubuntu.
Everything after the name that is not in `(...)` is read as a tail token, so
notes always go inside the parentheses.

* `<distro>` matches `$DISTRO` or `$DISTRO_FAMILY` (`ubuntu:`, `debian:`, `arch:`)
* backends:
  * `apt` / `aur` / `pacman` — native manager, under this name
  * `flatpak=<app id>` — from Flathub. Also gets a shim in `/usr/local/bin`
    (`exec flatpak run <app id>`) named like the native command — the canonical
    name minus `-bin` (`zen-browser-bin` → `zen-browser`), so WM keybinds, menu
    guards and scripts call it the same way on both distros
  * `bin=<command>` — the shim's name when that default is wrong
    (`visual-studio-code-bin ubuntu:flatpak=com.visualstudio.code ubuntu:bin=code`)
  * `snap=<name>`
  * `url=<link>` — a `.deb` / `.pkg.tar.zst` installed with the native manager
  * `ppa=<owner/repo>` — a **modifier**, not a method: adds the repo, then the
    package installs natively. Pair it with `apt=` when the name differs too
  * `source=<name>` — the escape hatch for anything needing a clone, a build or
    a vendor repo: runs `install_source_<name>` from `install/system/sources.sh`
    (return 0/non-zero). Reach for it last — every other backend needs no code
  * `skip` — nothing to install on this distro
* The picker never shows the tail, so both machines see an identical list.
* Descriptions are optional; package names never contain `(`.
* The parser sticks to POSIX `awk` / `sed` regexes (`[ \t]`, `[[:blank:]]`, never
  `\s` / `\w`): Arch's `awk` is gawk, but Ubuntu's is **mawk**, which silently
  doesn't match GNU escapes — that once made every category look empty.

**Adding a package:** add one line under its category. Check the Ubuntu name
(`apt-cache policy <name>`, or Flathub for GUI apps) and add a `ubuntu:` tail
only if it differs.

**Installing** goes through `install_packages <canonical>...` (`lib/helpers.sh`)
— the picker (`start_package_installation`) and `install_window_manager` both
call it, so nothing bypasses the per-distro mapping. It:

1. resolves every name (`resolve_package`) into a bucket: repos, native,
   flatpak, snap, url, source, skipped
2. prints the plan — skipped packages are named out loud, otherwise they would
   look installed — and asks once
3. adds the repositories first (a PPA package can't install before its PPA)
4. checks every native name with `pkg_available` — apt and pacman abort the
   whole transaction on a single unknown name, so unknown ones are reported as
   `missing:<name>` and dropped, the rest still install
5. installs the native bucket in one transaction, then flatpaks, snaps, urls and
   source builds
6. collects failures and reports them at the end instead of stopping at the
   first one (returns 2 → ✗ in the menu)

## `wrappers/`

WM configs (`niri/conf/autostart.kdl`, `hypr/conf/autostart.conf`) are shared by
both machines, so they can't hold a binary path that differs per distro — the
polkit agent is under `/usr/lib/polkit-gnome/` on Arch but
`/usr/lib/policykit-1-gnome/` on Ubuntu. They call a wrapper instead, which
resolves the path through `lib/paths.sh`:

* `polkit-agent.sh [gnome|mate]` — starts the polkit agent (falls back to the
  other one)
* `xdg-portals.sh <portal>...` — restarts the xdg-desktop-portal stack (Hyprland
  only; under niri the portals are systemd user units)

Wrappers source **`paths.sh` only, never `common.sh`**, so the gum bootstrap can
never run during compositor startup, and they exit 0 when nothing is installed
instead of failing the session's autostart.

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
  "Set env var|set_env|fish" \
  "Rain animation|terminal_rain|terminal-rain" \
  "System packages|package_commands"
```

Fish wrappers in `fish/functions/` just run the file and pass arguments:
`bash $HOME/Dotfiles/scripts/functions/terminal_rain.sh $argv`.

`system_packages.sh` defines `update_system` / `upgrade_system` (via `pkg_sync` / `pkg_upgrade`, so the same on both distros), and a `package_commands`
function that opens a submenu (it calls `menu` again). Having more than one entry
point, its dispatcher is generic (`… && "$@"`) so the caller — a fish wrapper or
the asd menu — names which function to run.

**Adding an alias:** drop a `<name>.sh` file here (or a subfolder with one, if it
needs its own assets) defining its function, then add a `"Label|<func>[|guard]"`
line to the `menu` call in `scripts/functions/alias_menu.sh`.

### `set-env` / `delete-env` and the current shell

All the logic lives in `set_env.sh` / `delete_env.sh`, which write the change to
`config.fish`. A bash child can't change its parent's env, so the fish wrapper
creates a temp file, passes it as `DOTFILES_FISH_OUT`, and after the script
exits sources it — the script puts a `set -gx NAME 'value'` / `set -e -g NAME`
line there via `fish_apply` (in `lib/helpers.sh`). The variable is live in the
current shell right away, no restart. Run from the `asd` menu there is no
wrapper, so the change only shows up in new terminals.

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
  folders**; `~` expands to home and `*` globs are supported (expanded with
  `compgen -G`, so profile dirs with spaces match), so a changing profile-folder
  name still matches.
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
