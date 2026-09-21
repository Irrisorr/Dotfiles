#!/bin/bash
#
# Distribution detection and the package-manager abstraction.
# Sourced by lib/common.sh BEFORE gum.sh — the gum bootstrap needs pkg_install.
# Standalone: must not pull in gum.sh/helpers.sh, so scripts/wrappers/* can use it.
#
#   DISTRO         raw ID from /etc/os-release (cachyos, ubuntu, ...)
#   DISTRO_FAMILY  arch | debian | unknown  ← always branch on this, not DISTRO
#   PKG_MGR        yay | pacman | apt

[ -n "$_DOTFILES_DISTRO" ] && return
_DOTFILES_DISTRO=1


# ─── Detection ────────────────────────────────────────────────────────────────

_detect_distro() {
  local id="" id_like=""

  if [ -r /etc/os-release ]; then
    id=$(. /etc/os-release 2>/dev/null && echo "$ID")
    id_like=$(. /etc/os-release 2>/dev/null && echo "$ID_LIKE")
  fi

  DISTRO="${id:-unknown}"

  # ID first, then ID_LIKE: CachyOS is ID=cachyos ID_LIKE=arch, Mint is
  # ID=linuxmint ID_LIKE="ubuntu debian".
  case " $id $id_like " in
    *" arch "*)                 DISTRO_FAMILY="arch"   ;;
    *" debian "*|*" ubuntu "*)  DISTRO_FAMILY="debian" ;;
    *)                          DISTRO_FAMILY="unknown" ;;
  esac
}

_detect_distro

case "$DISTRO_FAMILY" in
  arch)   command -v yay &>/dev/null && PKG_MGR="yay" || PKG_MGR="pacman" ;;
  debian) PKG_MGR="apt" ;;
  *)      PKG_MGR="" ;;
esac

export DISTRO DISTRO_FAMILY PKG_MGR

is_arch()   { [ "$DISTRO_FAMILY" = "arch" ]; }
is_debian() { [ "$DISTRO_FAMILY" = "debian" ]; }


_unsupported_distro() {
  if [ -z "$_DOTFILES_DISTRO_WARNED" ]; then
    _DOTFILES_DISTRO_WARNED=1
    echo ":: Unsupported distribution '$DISTRO' — package operations are disabled." >&2
    echo ":: Supported: Arch family (arch, cachyos, endeavouros) and Debian family (debian, ubuntu, mint)." >&2
  fi
  return 1
}


# ─── Package manager ──────────────────────────────────────────────────────────
#
# Functions, not command strings: apt needs DEBIAN_FRONTEND on the call, and
# word-splitting a "PKG_INSTALL" string breaks on names that need quoting.

pkg_install() {
  [ $# -eq 0 ] && return 0

  if is_arch; then
    if [ "$PKG_MGR" = "yay" ]; then
      yay -S --noconfirm --needed "$@"
    else
      sudo pacman -S --noconfirm --needed "$@"
    fi
  elif is_debian; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
  else
    _unsupported_distro
  fi
}


pkg_sync() {
  if is_arch; then
    if [ "$PKG_MGR" = "yay" ]; then
      yay -Sy
    else
      sudo pacman -Sy
    fi
  elif is_debian; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
  else
    _unsupported_distro
  fi
}


pkg_upgrade() {
  if is_arch; then
    if [ "$PKG_MGR" = "yay" ]; then
      yay -Syu --noconfirm
    else
      sudo pacman -Syu --noconfirm
    fi
  elif is_debian; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update \
      && sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
  else
    _unsupported_distro
  fi
}


pkg_installed() {
  if is_arch; then
    pacman -Qi "$1" &>/dev/null
  elif is_debian; then
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed$"
  else
    return 1
  fi
}


# Does the name exist in the repos? Decides if a package needs the source fallback.
pkg_available() {
  if is_arch; then
    if [ "$PKG_MGR" = "yay" ]; then
      yay -Si "$1" &>/dev/null
    else
      pacman -Si "$1" &>/dev/null
    fi
  elif is_debian; then
    apt-cache show "$1" &>/dev/null
  else
    return 1
  fi
}


# The command a user should run by hand, for error messages.
pkg_install_hint() {
  if is_arch; then
    echo "sudo pacman -S $1"
  elif is_debian; then
    echo "sudo apt install $1"
  else
    echo "install $1 with your package manager"
  fi
}


# ─── Flatpak ──────────────────────────────────────────────────────────────────
#
# Fallback for GUI apps in the AUR but not in apt (Zen, Obsidian, Postman, ...).
# Flathub is added --user: no root after the initial install.

ensure_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    echo ":: Installing flatpak..."
    pkg_install flatpak || return 1
  fi

  if ! flatpak remotes --columns=name | grep -qx "flathub"; then
    echo ":: Adding the Flathub remote..."
    flatpak remote-add --user --if-not-exists \
      flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
  fi
}


flatpak_install() {
  [ $# -eq 0 ] && return 0
  ensure_flatpak || return 1
  flatpak install --user --noninteractive --assumeyes flathub "$@"
}


# ─── Other install backends ───────────────────────────────────────────────────

snap_install() {
  [ $# -eq 0 ] && return 0
  command -v snap &>/dev/null || pkg_install snapd || return 1
  sudo snap install "$@"
}


# Download a .deb / .pkg.tar.zst and hand it to the native package manager, so
# dependencies still get resolved (dpkg -i alone would not).
url_install() {
  local url="$1" tmp rc
  [ -n "$url" ] || return 1

  command -v curl &>/dev/null || pkg_install curl || return 1
  tmp=$(mktemp -d) || return 1

  echo ":: Downloading $url"
  if curl -fsSL -o "$tmp/${url##*/}" "$url"; then
    if is_arch; then
      sudo pacman -U --noconfirm "$tmp/${url##*/}"
    else
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/${url##*/}"
    fi
    rc=$?
  else
    echo ":: Download failed: $url" >&2
    rc=1
  fi

  rm -rf "$tmp"
  return $rc
}


# add_repo <owner/repo> — a PPA on Debian; Arch has no equivalent, so it is a
# no-op there (an Arch line would use aur= instead).
add_repo() {
  local repo="$1"
  [ -n "$repo" ] || return 0
  is_debian || return 0

  command -v add-apt-repository &>/dev/null \
    || pkg_install software-properties-common || return 1

  sudo add-apt-repository -y "ppa:$repo" || return 1
  pkg_sync
}
