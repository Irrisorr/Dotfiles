#!/bin/bash
#
# Escape hatch for packages that no generic backend can express — anything
# needing a clone, a build, or a vendor repository.
#
# Reach for this LAST. apt / aur / flatpak / snap / url / ppa cover nearly
# everything, and they need no code at all — just a tail in packages.txt.
#
# Contract:  packages.txt "<distro>:source=<name>"  →  install_source_<name>
#
#   packages.txt:  clipse  ubuntu:source=clipse
#   here:          install_source_clipse() { ... }
#
# Return 0 on success, non-zero on failure — the installer collects failures
# and reports them at the end instead of aborting the whole run.

. "$HOME/Dotfiles/scripts/lib/common.sh"


# clipse has no Debian package or PPA, but upstream publishes prebuilt Wayland
# binaries. Installed into /usr/local/bin so it is on every PATH — including
# niri's, which runs `clipse -listen` at startup (~/go/bin would not be).
# Re-running the step upgrades it to the latest release.
install_source_clipse() {
  local arch tag tmp rc=0
  case "$(uname -m)" in
    x86_64)  arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) print_error_message "clipse: no release binary for $(uname -m)"; return 1 ;;
  esac

  command -v curl &>/dev/null || pkg_install curl || return 1
  tag=$(curl -fsSL https://api.github.com/repos/savedra1/clipse/releases/latest)
  tag=$(grep -m1 '"tag_name"' <<< "$tag" | cut -d'"' -f4)
  [ -n "$tag" ] || { print_error_message "clipse: could not find the latest release"; return 1; }

  tmp=$(mktemp -d)
  curl -fsSL "https://github.com/savedra1/clipse/releases/download/$tag/clipse_${tag}_linux_wayland_${arch}.tar.gz" \
    | tar -xz -C "$tmp" \
    && sudo install -m 755 "$tmp/clipse-linux-wayland-$arch" /usr/local/bin/clipse \
    || rc=1
  rm -rf "$tmp"

  [ $rc -eq 0 ] && echo ":: clipse $tag installed to /usr/local/bin/clipse"
  return $rc
}


# FreeOffice ships no versioned .deb URL. SoftMaker's installer sets up their
# apt repository, which is what makes the package upgrade with the system —
# so the repository is configured here directly instead of piping their script
# into a root shell. Values taken from install-softmaker-freeoffice-2024.sh.
install_source_freeoffice() {
  local keyring="/etc/apt/keyrings/softmaker.gpg"
  local list="/etc/apt/sources.list.d/softmaker.list"
  local key_url="https://shop.softmaker.com/repo/apt/softmaker-repo.asc"
  local repo_url="https://shop.softmaker.com/repo/apt"

  is_debian || { print_error_message "freeoffice: Debian-family only"; return 1; }

  pkg_install gnupg ca-certificates curl || return 1

  sudo mkdir -p /etc/apt/keyrings || return 1
  curl -fsSL "$key_url" | sudo gpg --dearmor --yes -o "$keyring" || return 1
  sudo chmod 0644 "$keyring"

  echo "deb [arch=amd64 signed-by=$keyring] $repo_url stable non-free" \
    | sudo tee "$list" >/dev/null || return 1

  pkg_sync || return 1
  pkg_install softmaker-freeoffice-2024
}


# Goodix 27c6:550a fingerprint driver.
#
# Arch: the AUR driver needs libfprint-tod, which conflicts with the plain
# libfprint that fprintd pulls from the repos. pacman asks before swapping them
# and --noconfirm answers "no", so the whole AUR transaction fails. Swap them
# here instead: drop libfprint without its dependants (libfprint-tod provides
# it, so fprintd stays satisfied), then install, and put libfprint back if that
# fails so fprintd is never left without it.
#
# Ubuntu: the PPA has no 26.04 build, so the noble .deb the AUR package
# repackages is installed directly; apt pulls libfprint-2-tod1 from the archive.
# Does not update by itself.
install_source_goodix() {
  if is_debian; then
    url_install "https://launchpad.net/~libfprint-tod1-group/+archive/ubuntu/ppa/+files/libfprint-2-tod1-goodix-550a_0.0.11+2404-0ubuntu1_amd64.deb"
    return
  fi

  # `pacman -Qq libfprint` resolves provides: it prints libfprint-tod once that
  # is installed, so only the plain package is swapped out.
  if [ "$(pacman -Qq libfprint 2>/dev/null)" = "libfprint" ]; then
    sudo pacman -Rdd --noconfirm libfprint || return 1
  fi

  if ! pkg_install libfprint-tod libfprint-2-tod1-goodix-v2; then
    pacman -Qq libfprint &>/dev/null || pkg_install libfprint
    return 1
  fi
}


# JetBrains Mono Nerd Font — kitty, fastfetch and DMS use its icons. apt ships
# only the plain font, so the official nerd-fonts release is installed system
# wide instead (the same font Arch's ttf-jetbrains-mono-nerd packages).
# Re-running the step upgrades it to the latest release.
install_source_jetbrains_nerd() {
  local dir="/usr/local/share/fonts/JetBrainsMonoNerd"
  command -v curl &>/dev/null || pkg_install curl || return 1
  command -v fc-cache &>/dev/null || pkg_install fontconfig || return 1

  sudo mkdir -p "$dir" \
    && curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
       | sudo tar -xJ -C "$dir" \
    && sudo fc-cache -f "$dir" >/dev/null \
    || return 1

  echo ":: JetBrainsMono Nerd Font installed to $dir"
}
