#!/bin/bash
#
# Resolvers for paths that differ between distributions.
# Standalone like distro.sh: scripts/wrappers/* source it without common.sh.
#
# Rule: CANDIDATE LISTS, not `if is_arch`. Each resolver returns the first path
# that exists, Arch's listed first — so unusual layouts still resolve and
# behaviour on Arch is unchanged.

[ -n "$_DOTFILES_PATHS" ] && return
_DOTFILES_PATHS=1

[ -n "$_DOTFILES_DISTRO" ] || . "$HOME/Dotfiles/scripts/lib/distro.sh"


_first_existing() {
  local p
  for p in "$@"; do
    [ -e "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}


_first_executable() {
  local p
  for p in "$@"; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}


# ─── polkit authentication agents ─────────────────────────────────────────────
#
# Also needed by the WM autostart configs, which are shared between machines and
# cannot hold a distro-specific path — those go through wrappers/polkit-agent.sh.

find_polkit_agent() {
  case "${1:-gnome}" in
    gnome)
      _first_executable \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
        /usr/libexec/polkit-gnome-authentication-agent-1 \
        /usr/libexec/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
        /usr/lib/x86_64-linux-gnu/polkit-gnome/polkit-gnome-authentication-agent-1
      ;;
    mate)
      _first_executable \
        /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 \
        /usr/lib/x86_64-linux-gnu/mate-polkit/polkit-mate-authentication-agent-1 \
        /usr/libexec/polkit-mate-authentication-agent-1
      ;;
    *)
      return 1
      ;;
  esac
}

# Menu guards: test:has_polkit_gnome
has_polkit_gnome() { find_polkit_agent gnome >/dev/null; }
has_polkit_mate()  { find_polkit_agent mate  >/dev/null; }


# ─── xdg-desktop-portal ───────────────────────────────────────────────────────

# Portals are libexec-style helpers, not on $PATH: Arch /usr/lib, Debian /usr/libexec.
find_portal_binary() {
  [ -n "$1" ] || return 1
  _first_executable \
    "/usr/lib/$1" \
    "/usr/libexec/$1" \
    "/usr/lib/x86_64-linux-gnu/$1" \
    "/usr/lib/aarch64-linux-gnu/$1"
}


# ─── SDDM ─────────────────────────────────────────────────────────────────────

# NOTE: /usr/lib/sddm/sddm.conf.d is the VENDOR dir — a package upgrade can
# overwrite it. /etc/sddm.conf.d is the admin dir and wins over it. An existing
# dir is preferred so this keeps writing where it already does.
sddm_confd_dir() {
  _first_existing /usr/lib/sddm/sddm.conf.d /etc/sddm.conf.d && return 0
  echo /etc/sddm.conf.d
}


sddm_themes_dir() {
  _first_existing /usr/share/sddm/themes /usr/local/share/sddm/themes && return 0
  echo /usr/share/sddm/themes
}


# ─── Shell ────────────────────────────────────────────────────────────────────

# Arch symlinks /bin -> /usr/bin so /bin/fish works there; Ubuntu ships
# /usr/bin/fish and omits /bin/fish from /etc/shells, so `chsh -s /bin/fish` fails.
fish_bin() {
  command -v fish 2>/dev/null
}


# chsh refuses any shell absent from /etc/shells, so register it first.
ensure_login_shell() {
  local shell_path="$1"

  [ -x "$shell_path" ] || {
    echo ":: Not an executable shell: $shell_path" >&2
    return 1
  }

  if ! grep -qxF "$shell_path" /etc/shells 2>/dev/null; then
    echo ":: Registering $shell_path in /etc/shells"
    echo "$shell_path" | sudo tee -a /etc/shells >/dev/null || return 1
  fi

  if [ "$SHELL" = "$shell_path" ]; then
    echo ":: $shell_path is already the login shell"
    return 0
  fi

  chsh -s "$shell_path"
}


# ─── Python ───────────────────────────────────────────────────────────────────

# Arch installs into site-packages, Debian into dist-packages.
python_site_dir() {
  local ver
  ver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null) \
    || return 1

  _first_existing \
    "/usr/lib/python${ver}/site-packages" \
    "/usr/lib/python3/dist-packages" \
    "/usr/lib/python${ver}/dist-packages"
}


# ─── Console font ─────────────────────────────────────────────────────────────

# Arch: FONT= in /etc/vconsole.conf. Debian: console-setup wants a face+size
# pair, not a font file name — "cyr-sun16" maps to Terminus 16 (same coverage).
set_console_font() {
  local font="$1"

  if is_arch; then
    if grep -q "^FONT=" /etc/vconsole.conf 2>/dev/null; then
      sudo sed -i "s/^FONT=.*/FONT=$font/" /etc/vconsole.conf
    else
      echo "FONT=$font" | sudo tee -a /etc/vconsole.conf >/dev/null
    fi
    sudo systemctl restart systemd-vconsole-setup.service

  elif is_debian; then
    local conf="/etc/default/console-setup"
    sudo touch "$conf"

    _console_setup_key() {
      local key="$1" value="$2"
      if grep -q "^${key}=" "$conf"; then
        sudo sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$conf"
      else
        echo "${key}=\"${value}\"" | sudo tee -a "$conf" >/dev/null
      fi
    }

    _console_setup_key CODESET  "CyrKoi"
    _console_setup_key FONTFACE "Terminus"
    _console_setup_key FONTSIZE "16x32"

    sudo setupcon --save 2>/dev/null || sudo systemctl restart console-setup.service

  else
    echo ":: Don't know how to set the console font on '$DISTRO'." >&2
    return 1
  fi
}
