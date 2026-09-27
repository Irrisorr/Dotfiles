#!/bin/bash
#
# Generic reusable helpers: the universal menu, execute_*, create_symlink, the
# package selection engine, and system_update. Sourced via common.sh, which
# loads lib/gum.sh first — do not source gum.sh here.
# App/system-specific config logic lives in scripts/install/{system,apps}/, not here.

declare -A SELECTED_PACKAGES
declare -A ACTION_STATUS
declare -A _PKG_SPEC


# ─── Universal menu ───────────────────────────────────────────────────────────
#
# menu <back_label> <entry>...
#
#   entry = "Label|function"          — run `function` when picked
#           "Label|function|guard"    — same, but hidden unless the guard passes
#
#   guard = tok[+tok...]   all tokens must pass
#     distro:<id>   matches $DISTRO or $DISTRO_FAMILY  (distro:arch, distro:debian)
#     test:<func>   runs the shell function, uses its exit status
#     <anything>    `command -v` — a bare name or an absolute path
#
# Each entry maps a display label (decoupled from the function name) to a
# function. A function may itself call `menu` again to open a submenu — the
# submenu's own back button returns to this one. The <back_label> entry (e.g.
# "⬅ Back", "Continue") is always appended last; picking it returns 0.
# Per-function ✓/✗ status is tracked and shown.
guard_passes() {
  local tok
  for tok in ${1//+/ }; do
    case "$tok" in
      distro:*)
        local want="${tok#distro:}"
        [ "$want" = "$DISTRO" ] || [ "$want" = "$DISTRO_FAMILY" ] || return 1
        ;;
      test:*)
        "${tok#test:}" || return 1
        ;;
      *)
        command -v "$tok" &>/dev/null || return 1
        ;;
    esac
  done
}


menu() {
  local back_label="$1"; shift
  local entries=("$@")

  require_gum "menu" || return 1

  while true; do
    local options=() funcs=()

    for e in "${entries[@]}"; do
      local label="${e%%|*}"
      local rest="${e#*|}"
      local func="${rest%%|*}"
      local guard=""
      [ "$rest" != "$func" ] && guard="${rest#*|}"

      if [ -n "$guard" ] && ! guard_passes "$guard"; then
        continue
      fi

      local mark="  "
      [ "${ACTION_STATUS[$func]}" = "✓" ] && mark="✓ "
      [ "${ACTION_STATUS[$func]}" = "✗" ] && mark="✗ "

      options+=("$mark$label")
      funcs+=("$func")
    done

    options+=("$back_label")

    local choice
    choice=$(gum_choose_wrapper --height 30 "${options[@]}")

    local rc=$?
    [ $rc -eq 130 ] && exit 130   # Ctrl+C → quit the whole menu immediately
    [ $rc -ne 0 ] && exit 130     # Esc / cancel → quit the whole menu
    [ "$choice" = "$back_label" ] && return 0

    local i
    for i in "${!funcs[@]}"; do
      if [ "${options[$i]}" = "$choice" ]; then
        "${funcs[$i]}"
        local rc=$?
        if [ $rc -eq 0 ]; then
          ACTION_STATUS[${funcs[$i]}]="✓"
        elif [ $rc -eq 1 ]; then
          ACTION_STATUS[${funcs[$i]}]=""
        else
          ACTION_STATUS[${funcs[$i]}]="✗"
        fi
        break
      fi
    done
  done
}


# fish_apply <fish command> — run a command in the calling fish shell.
# A bash child can't change its parent's env (and `exec fish` from here only
# nests a new fish inside the old one), so the fish wrapper passes a file in
# DOTFILES_FISH_OUT and sources it after this script exits. Without a wrapper
# (e.g. the asd menu) the change still lands in config.fish for new terminals.
fish_apply() {
  if [ -n "$DOTFILES_FISH_OUT" ]; then
    printf '%s\n' "$1" >> "$DOTFILES_FISH_OUT"
  else
    echo ":: Open a new terminal to apply the change"
  fi
}


# Quote a value for fish: inside '...' only \ and ' need escaping.
fish_quote() {
  local s="${1//\\/\\\\}"
  printf "'%s'" "${s//\'/\\\'}"
}


# ─── packages.txt parsing ─────────────────────────────────────────────────────
#
# One line per package — add it once and it works on both distros:
#
#   <canonical> [<distro>:<backend>[=<value>]]... [(description)]
#
# <canonical> is the Arch name and the key everything else uses. An override
# tail is only needed when a distro actually differs:
#
#   neovim                                    same name everywhere
#   sqlite                 ubuntu:apt=sqlite3
#   zen-browser-bin        ubuntu:flatpak=app.zen_browser.zen
#   dms-shell-bin          ubuntu:source=dms
#   logmein-hamachi        ubuntu:skip        no equivalent, don't try
#
# backend ∈ apt | aur | pacman | flatpak | snap | url | ppa | source | skip
#   apt/aur/pacman  → "native", the distro's own package manager
#   url             → download a .deb/.pkg.tar.zst and install it natively
#   ppa             → a modifier, not a method: adds the repo, then installs
#                     normally. Pair it with apt= when the name also differs:
#                       dms-shell-bin  ubuntu:ppa=avengemedia/dms ubuntu:apt=dms
#   source          → escape hatch for the rare package that needs real logic;
#                     runs install_source_<value> from install/sources.sh
#
# No override for the running distro → native, canonical name.
# The picker never shows the override tail, so both machines see the same list.

# Split a line into its canonical name (_PKG_NAME) and override tail (_PKG_TAIL).
# Package names never contain "(", descriptions always start with one.
_split_package_line() {
  local head="${1%%(*}"
  read -r _PKG_NAME _PKG_TAIL <<< "$head"
}


load_package_index() {
  [ -n "$_PKG_INDEX_LOADED" ] && return 0

  # Without it every package would silently resolve to the native default.
  [ -r "$INSTALL_DIR/packages.txt" ] || {
    echo ":: Cannot read $INSTALL_DIR/packages.txt" >&2
    return 1
  }

  local line
  while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    _split_package_line "$line"
    [ -n "$_PKG_NAME" ] && _PKG_SPEC["$_PKG_NAME"]="$_PKG_TAIL"
  done < "$INSTALL_DIR/packages.txt"

  _PKG_INDEX_LOADED=1
}


# resolve_package <canonical> → "<backend>\t<value>\t<repo>"
#   backend ∈ native | flatpak | snap | url | source | skip
#   repo is empty unless a ppa= token asked for one — and it is LAST because
#   `read` with IFS=tab strips a leading empty field (tab counts as whitespace),
#   which would shift every column when there is no repo.
resolve_package() {
  load_package_index || return 1

  local name="$1" tok backend value
  local repo="" out_backend="" out_value=""

  for tok in ${_PKG_SPEC["$name"]}; do
    case "$tok" in
      "$DISTRO":* | "$DISTRO_FAMILY":*) ;;
      *) continue ;;
    esac

    tok="${tok#*:}"
    backend="${tok%%=*}"
    value="${tok#*=}"
    [ "$backend" = "$value" ] && value="$name"   # bare "ubuntu:skip", no =value

    case "$backend" in
      ppa | repo) repo="$value"; continue ;;
      apt | aur | pacman) backend="native" ;;
    esac

    out_backend="$backend"
    out_value="$value"
  done

  printf '%s\t%s\t%s\n' "${out_backend:-native}" "${out_value:-$name}" "$repo"
}


# Strip the override tail for display, keeping "<name> (description)".
# Lines without a tail are passed through untouched so their alignment survives.
_package_display_line() {
  local line="$1" head desc
  head="${line%%(*}"
  desc="${line:${#head}}"

  _split_package_line "$line"

  if [ -z "$_PKG_TAIL" ]; then
    printf '%s\n' "$line"
  elif [ -n "$desc" ]; then
    printf '%s %s\n' "$_PKG_NAME" "$desc"
  else
    printf '%s\n' "$_PKG_NAME"
  fi
}


# ─── Package selection engine ─────────────────────────────────────────────────

# Function to handle interactive category selection and package selection
package_category_selection() {
  local package_file="$INSTALL_DIR/packages.txt"

  require_gum "package installation" || return 1

  while true; do
    local categories_array=()
    local category_status=()

    while IFS= read -r category; do
      categories_array+=("$category")

      if [ -n "${SELECTED_PACKAGES[$category]}" ]; then
        category_status+=("✓ $category")
      else
        category_status+=("  $category")
      fi
    done < <(echo "$(get_all_categories)")

    category_status+=("⏭️ Skip Package Installation")
    category_status+=("🚀 Start Installation")

    print_styled_message "Package Installation
Select Package Categories
Navigate with arrows, ENTER to confirm"
    echo ""

    local choice
    choice=$(gum_choose_wrapper --height 30 "${category_status[@]}")

    if [ $? -ne 0 ]; then
      echo ""
      continue
    fi

    if [ "$choice" = "🚀 Start Installation" ]; then
      start_package_installation
      break
    elif [ "$choice" = "⏭️ Skip Package Installation" ]; then
      print_styled_message "Skipping package installation"
      break
    else
      local clean_choice=$(echo "$choice" | sed 's/^[✓ ]\s*//')
      select_packages_for_category "$clean_choice"
    fi
    echo ""
  done
}


# Function to get all categories from the packages.txt file
get_all_categories() {
  local package_file="$INSTALL_DIR/packages.txt"
  grep '^#' "$package_file" | sed 's/^#\s*//'
}


start_package_installation() {
  local -a names=()
  local category line

  print_styled_message "Preparing to install selected packages..."
  echo ""

  for category in "${!SELECTED_PACKAGES[@]}"; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      _split_package_line "$line"   # trims the description and any padding
      [ -n "$_PKG_NAME" ] && names+=("$_PKG_NAME")
    done <<< "${SELECTED_PACKAGES[$category]}"
  done

  install_packages "${names[@]}"
}


# install_packages <canonical>... — the single entry point for installing
# anything listed in packages.txt, so every caller gets the per-distro mapping
# (PPAs, flatpak, source builds) instead of a raw pkg_install.
#
# Plan first, then execute. resolve_package sorts every name into a bucket per
# backend, so one run can mix repo packages, flatpaks and source builds.
install_packages() {
  local -a native=() flat=() snaps=() urls=() src=() skipped=()
  local -A repos=()
  local name repo backend value

  for name in "$@"; do
    IFS=$'\t' read -r backend value repo < <(resolve_package "$name")
    [ -n "$repo" ] && repos["$repo"]=1

    case "$backend" in
      native)  native+=("$value") ;;
      flatpak) flat+=("$value")   ;;
      snap)    snaps+=("$value")  ;;
      url)     urls+=("$value")   ;;
      source)  src+=("$value")    ;;
      skip)    skipped+=("$name") ;;
    esac
  done

  local total=$(( ${#native[@]} + ${#flat[@]} + ${#snaps[@]} + ${#urls[@]} + ${#src[@]} ))
  if [ $(( total + ${#skipped[@]} )) -eq 0 ]; then
    print_error_message "No packages selected!"
    return 1
  fi

  [ ${#repos[@]}  -gt 0 ] && echo "  • repos:   ${!repos[*]}"
  [ ${#native[@]} -gt 0 ] && echo "  • $PKG_MGR:  ${native[*]}"
  [ ${#flat[@]}   -gt 0 ] && echo "  • flatpak: ${flat[*]}"
  [ ${#snaps[@]}  -gt 0 ] && echo "  • snap:    ${snaps[*]}"
  [ ${#urls[@]}   -gt 0 ] && echo "  • url:     ${urls[*]}"
  [ ${#src[@]}    -gt 0 ] && echo "  • source:  ${src[*]}"
  # Loudly: a skipped package looks installed otherwise.
  [ ${#skipped[@]} -gt 0 ] && echo "  • SKIPPED on $DISTRO (no equivalent): ${skipped[*]}"
  echo ""

  if [ $total -eq 0 ]; then
    print_error_message "Nothing to install on $DISTRO"
    return 1
  fi

  print_styled_message "Total: $total packages"
  confirm_action "start installation" || return 1

  # Collect failures instead of aborting — one bad AUR build should not stop
  # the flatpaks behind it.
  local -a failed=()

  # Repos first — a package from a PPA cannot install before its PPA is added.
  for repo in "${!repos[@]}"; do
    print_styled_message "Adding repository $repo"
    add_repo "$repo" || failed+=("repo:$repo")
  done

  # apt and pacman abort the whole transaction on one unknown name, so filter
  # first. Checked only now, after the repos: PPA packages are invisible before.
  if [ ${#native[@]} -gt 0 ]; then
    local -a available=()
    echo ":: Checking availability of ${#native[@]} packages..."
    for value in "${native[@]}"; do
      if pkg_available "$value"; then
        available+=("$value")
      else
        print_error_message "Not found in $PKG_MGR repos: $value"
        failed+=("missing:$value")
      fi
    done
    native=("${available[@]}")
  fi

  if [ ${#native[@]} -gt 0 ]; then
    print_styled_message "Installing ${#native[@]} packages with $PKG_MGR"
    pkg_install "${native[@]}" || failed+=("$PKG_MGR")
  fi

  if [ ${#flat[@]} -gt 0 ]; then
    print_styled_message "Installing ${#flat[@]} flatpaks"
    for value in "${flat[@]}"; do
      flatpak_install "$value" || failed+=("flatpak:$value")
    done
  fi

  if [ ${#snaps[@]} -gt 0 ]; then
    print_styled_message "Installing ${#snaps[@]} snaps"
    for value in "${snaps[@]}"; do
      snap_install "$value" || failed+=("snap:$value")
    done
  fi

  for value in "${urls[@]}"; do
    print_styled_message "Installing from ${value##*/}"
    url_install "$value" || failed+=("url:$value")
  done

  for value in "${src[@]}"; do
    if ! declare -F "install_source_$value" >/dev/null; then
      print_error_message "No installer for '$value' (expected install_source_$value in $SYSTEM_DIR/sources.sh)"
      failed+=("source:$value")
      continue
    fi
    print_styled_message "Building $value from source"
    "install_source_$value" || failed+=("source:$value")
  done

  if [ ${#failed[@]} -gt 0 ]; then
    print_error_message "Failed: ${failed[*]}"
    return 2
  fi

  print_success_message "All packages installed successfully!"
}


# Function to handle package selection for a specific category
select_packages_for_category() {
  local category=$1

  print_styled_message "Selecting packages from: $category
Navigate with arrows, SPACE to select
ENTER to confirm
ESC or ENTER without selection to cancel"
  echo ""

  local app_list
  app_list=$(get_packages_from_category "$category")

  if [ -z "$app_list" ]; then
    print_error_message "Category '$category' is empty or not found"
    return 1
  fi

  local options_array=()
  while IFS= read -r line; do
    options_array+=("$line")
  done <<<"$app_list"

  local selected

  # Re-select whatever was picked last time, so reopening a category is not a reset.
  if [ -n "${SELECTED_PACKAGES[$category]}" ]; then
    local cmd_args=("--multi" "--height" "15")
    while IFS= read -r pkg; do
      cmd_args+=("--selected" "$pkg")
    done <<<"${SELECTED_PACKAGES[$category]}"

    selected=$(gum_choose_wrapper "${cmd_args[@]}" "${options_array[@]}")
  else
    selected=$(gum_choose_wrapper --multi --height 15 "${options_array[@]}")
  fi

  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo ":: Selection cancelled"
    echo ""
    sleep 1
    return 0
  fi

  if [ -n "$selected" ]; then
    SELECTED_PACKAGES["$category"]="$selected"
    local pkg_count=$(echo "$selected" | wc -l)
    print_success_message "Saved $pkg_count package(s) for $category"
  else
    unset SELECTED_PACKAGES["$category"]
    echo ":: No packages selected"
  fi

  echo ""
  sleep 1
}


# Function to get packages from a specific category in the packages.txt file
get_packages_from_category() {
  local category_to_find="$1"
  local package_file="$INSTALL_DIR/packages.txt"

  local line
  awk -v category="$category_to_find" '
    BEGIN { p=0 }
    /^#/ {
        if (p) { exit }
        gsub(/^#\s*/, "");
        if ($0 == category) { p=1 }
        next
    }
    p { print }
  ' "$package_file" | while IFS= read -r line; do
    _package_display_line "$line"
  done
}


# ─── Execution helpers ────────────────────────────────────────────────────────

# Function to execute a command and check its success
execute_script() {
  "$@"
  check_success "Command execution: $*"
}


# Run a command after confirmation. Return codes follow menu(): 1 = declined
# (no mark), 2 = failed (✗), so a real failure is never shown as skipped.
execute_command() {
  local message=$1
  local script=$2

  print_styled_message "$message"
  confirm_action "$message" || return 1

  if bash -c ". $HOME/Dotfiles/scripts/lib/common.sh && $script"; then
    print_success_message "$message"
  else
    print_error_message "Failed to $message"
    return 2
  fi
}


# Replace <target> with a symlink to <source>. Whatever was there before (a
# real config from another install) is kept as <target>.bak; a stale symlink is
# just replaced.
create_symlink() {
  local source=$1
  local target=$2

  # Target already resolves to source — either our link, or a path inside a
  # symlinked dir (~/.config/hypr/x when ~/.config/hypr -> Dotfiles/hypr).
  # Touching it would move the repo's own file to .bak and self-link it.
  if [ -e "$target" ] && [ "$(realpath "$target")" = "$(realpath "$source")" ]; then
    echo ":: Already linked: $target"
    return 0
  fi

  if [ -L "$target" ]; then
    echo ":: Replacing old symlink $target"
    rm "$target"
  elif [ -e "$target" ]; then
    local backup="${target}.bak"
    # mv into an existing .bak dir would nest instead of rename.
    [ -e "$backup" ] && backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    echo ":: Backing up existing $target -> $backup"
    mv "$target" "$backup" || return 2
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  check_success "Created symlink from $source to $target"
}


# Reused by install.sh and post_install.sh
system_update() {
  execute_command "Update the system" 'pkg_upgrade'
}
