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
#
# Optional:  installed_source_<name>  — returns 0 when it is already installed,
# so the package picker can mark it ✓. Without one the entry shows no mark.

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


# Google Antigravity — no .deb, apt repo or flatpak for the 2.x app; Google only
# publishes a tarball whose URL carries a build id. The download page embeds the
# current one, so it is read from there (the same tarball the AUR package uses).
# Installed like the AUR package: /opt/Antigravity + a launcher and .desktop.
# Re-running the step upgrades it.
install_source_antigravity() {
  local arch url tmp rc=0
  case "$(uname -m)" in
    x86_64)  arch=linux-x64 ;;
    aarch64) arch=linux-arm ;;
    *) print_error_message "antigravity: no build for $(uname -m)"; return 1 ;;
  esac

  command -v curl &>/dev/null || pkg_install curl || return 1
  url=$(curl -fsSL "https://antigravity.google/download?os=linux" \
        | grep -oE "https://storage.googleapis.com/antigravity-public/antigravity-hub/[0-9][^\"]*/$arch/Antigravity\.tar\.gz" \
        | head -n 1)
  [ -n "$url" ] || { print_error_message "antigravity: download link not found on antigravity.google"; return 1; }

  tmp=$(mktemp -d)
  echo ":: Downloading $url"
  if curl -fsSL "$url" | tar -xz -C "$tmp"; then
    # chrome-sandbox must be setuid root: Ubuntu's AppArmor blocks the
    # unprivileged user namespaces Electron would use instead.
    # The tarball has no icon file; the AUR package ships one.
    sudo rm -rf /opt/Antigravity \
      && sudo cp -a "$tmp"/Antigravity-*/ /opt/Antigravity \
      && sudo chown root:root /opt/Antigravity/chrome-sandbox \
      && sudo chmod 4755 /opt/Antigravity/chrome-sandbox \
      && sudo ln -sf /opt/Antigravity/antigravity /usr/local/bin/antigravity \
      && curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity.png?h=antigravity" \
         | sudo tee /usr/share/pixmaps/antigravity.png >/dev/null \
      && printf '%s\n' "[Desktop Entry]" "Name=Antigravity" "GenericName=Agentic Platform" \
           "Exec=/usr/local/bin/antigravity %U" "Icon=antigravity" \
           "Type=Application" "StartupWMClass=Antigravity" "Categories=Development;Utility;" \
         | sudo tee /usr/share/applications/antigravity.desktop >/dev/null \
      || rc=1
  else
    print_error_message "antigravity: download failed"
    rc=1
  fi
  rm -rf "$tmp"
  return $rc
}


# Zen — not in apt, and the flatpak's read-only app dir can't take Sine's
# bootloader. The AUR package is upstream's tarball, so that is used here too,
# unpacked into ~/.local/share/zen and owned by the user: Zen's own updater
# (linux.mar) keeps it current from inside the browser, and Sine installs
# without root. Linked into /usr/local/bin as zen-browser, the Arch package's
# name, for niri's keybinds and the menu guards. Re-running the step reinstalls
# the latest release; Sine's bootloader files are carried over.
install_source_zen() {
  local arch tmp f dir="$ZEN_TARBALL_DIR" rc=0
  [ -n "$dir" ] || return 1   # rm -rf below
  case "$(uname -m)" in
    x86_64|aarch64) arch=$(uname -m) ;;
    *) print_error_message "zen: no build for $(uname -m)"; return 1 ;;
  esac
  command -v curl &>/dev/null || pkg_install curl || return 1

  tmp=$(mktemp -d)
  echo ":: Downloading Zen ($arch)"
  if curl -fsSL "https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-$arch.tar.xz"        | tar -xJ -C "$tmp"; then
    for f in config.js defaults/pref/config-prefs.js; do
      [ -f "$dir/$f" ] || continue
      mkdir -p "$tmp/zen/$(dirname "$f")" && cp -a "$dir/$f" "$tmp/zen/$f"
    done
    rm -rf "$dir" \
      && mkdir -p "$(dirname "$dir")" "$HOME/.local/share/applications" \
      && mv "$tmp/zen" "$dir" \
      && sudo ln -sf "$dir/zen" /usr/local/bin/zen-browser \
      && printf '%s\n' "[Desktop Entry]" "Name=Zen Browser" "GenericName=Web Browser" \
           "Exec=/usr/local/bin/zen-browser %u" "Icon=$dir/browser/chrome/icons/default/default128.png" \
           "Type=Application" "StartupWMClass=zen" "StartupNotify=true" \
           "Categories=Network;WebBrowser;" \
           "MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;" \
         > "$HOME/.local/share/applications/zen.desktop" \
      || rc=1
  else
    print_error_message "zen: download failed"
    rc=1
  fi
  rm -rf "$tmp"
  return $rc
}


# Latest GitHub release tag of <owner/repo>.
_github_latest_tag() {
  local json
  json=$(curl -fsSL "https://api.github.com/repos/$1/releases/latest") || return 1
  grep -m1 '"tag_name"' <<< "$json" | cut -d'"' -f4
}


# kitty — Ubuntu 26.04 freezes it at 0.45, which lacks custom_shaders and other
# options kitty.conf uses. Upstream's own build (what its installer.sh fetches)
# goes into /opt/kitty.app, linked into /usr/local/bin so niri's keybinds find
# it. It bundles its own Python, terminfo and slangc — kitty looks slangc up on
# PATH for custom_shaders, so that is linked too. Re-running the step upgrades it.
install_source_kitty() {
  local tag arch tmp rc=0
  case "$(uname -m)" in
    x86_64)  arch=x86_64 ;;
    aarch64) arch=arm64 ;;
    *) print_error_message "kitty: no build for $(uname -m)"; return 1 ;;
  esac
  command -v curl &>/dev/null || pkg_install curl || return 1
  tag=$(_github_latest_tag kovidgoyal/kitty) || { print_error_message "kitty: could not find the latest release"; return 1; }

  tmp=$(mktemp -d)
  echo ":: Downloading kitty $tag"
  if curl -fsSL "https://github.com/kovidgoyal/kitty/releases/download/$tag/kitty-${tag#v}-$arch.txz" | tar -xJ -C "$tmp"; then
    sudo rm -rf /opt/kitty.app \
      && sudo cp -a "$tmp" /opt/kitty.app \
      && sudo chmod 755 /opt/kitty.app \
      && sudo ln -sf /opt/kitty.app/bin/kitty /usr/local/bin/kitty \
      && sudo ln -sf /opt/kitty.app/bin/kitten /usr/local/bin/kitten \
      && sudo ln -sf /opt/kitty.app/bin/slangc /usr/local/bin/slangc \
      && sed "s|^Icon=kitty|Icon=/opt/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|; s|^Exec=kitty|Exec=/usr/local/bin/kitty|" \
           /opt/kitty.app/share/applications/kitty.desktop \
         | sudo tee /usr/share/applications/kitty.desktop >/dev/null \
      || rc=1
  else
    print_error_message "kitty: download failed"
    rc=1
  fi
  rm -rf "$tmp"
  return $rc
}


# swayimg — Ubuntu 26.04 ships 4.7, older than the Lua config (5.0+) that
# swayimg/init.lua is written in, and upstream has no binaries, flatpak or PPA.
# Built from the release tag into /usr/local. Every image format is optional in
# meson; the -dev packages here switch them on. EXR stays off: swayimg needs
# OpenEXR >= 3.4, Ubuntu has 3.1. apt's 4.7 is removed so the menu has one
# entry. Re-running the step upgrades it.
_SWAYIMG_BUILD_DEPS=(
  meson ninja-build g++ pkg-config python3
  libwayland-dev wayland-protocols libxkbcommon-dev libfontconfig-dev
  libfreetype-dev libluajit-5.1-dev libdrm-dev libexiv2-dev
  libjpeg-dev libpng-dev libwebp-dev libgif-dev libheif-dev libavif-dev
  libjxl-dev librsvg2-dev libtiff-dev libraw-dev libopenjp2-7-dev libsixel-dev
  libminizip-ng-dev libavformat-dev libavcodec-dev libavutil-dev libswscale-dev
)

install_source_swayimg() {
  local tag tmp jobs mem_kb rc=0
  command -v curl &>/dev/null || pkg_install curl || return 1
  pkg_install "${_SWAYIMG_BUILD_DEPS[@]}" || return 1
  tag=$(_github_latest_tag artemsen/swayimg) || { print_error_message "swayimg: could not find the latest release"; return 1; }

  # The biggest g++ job here peaks at ~525 MB (measured on 5.7). ninja's
  # default (cores + 2) swapped a 12-core VM with 4 GB to a standstill, so
  # jobs follow free memory: one per 800 MB.
  mem_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
  jobs=$(( mem_kb / 800000 ))
  [ "$jobs" -lt 1 ] && jobs=1
  [ "$jobs" -gt "$(nproc)" ] && jobs=$(nproc)

  tmp=$(mktemp -d)
  echo ":: Building swayimg $tag ($jobs parallel jobs for $(( mem_kb / 1024 )) MB free)"
  if curl -fsSL "https://github.com/artemsen/swayimg/archive/refs/tags/$tag.tar.gz" \
       | tar -xz -C "$tmp" --strip-components=1; then
    meson setup "$tmp/build" "$tmp" --prefix=/usr/local --buildtype=release \
        -Dversion="${tag#v}" -Dexr=disabled \
      && meson compile -C "$tmp/build" -j "$jobs" \
      && sudo meson install -C "$tmp/build" --no-rebuild \
      || rc=1
  else
    print_error_message "swayimg: download failed"
    rc=1
  fi
  rm -rf "$tmp"

  if [ $rc -eq 0 ] && pkg_installed swayimg; then
    sudo apt-get remove -y swayimg
  fi
  return $rc
}


# ─── Installed checks for the package picker (see the contract above) ─────────

installed_source_clipse()         { command -v clipse &>/dev/null; }
installed_source_jetbrains_nerd() { fc-list 2>/dev/null | grep -q "JetBrainsMono Nerd"; }
installed_source_freeoffice()     { pkg_installed softmaker-freeoffice-2024; }
installed_source_goodix() {
  if is_debian; then
    pkg_installed libfprint-2-tod1-goodix-550a
  else
    pkg_installed libfprint-2-tod1-goodix-v2
  fi
}
installed_source_antigravity()     { [ -x /opt/Antigravity/antigravity ]; }
installed_source_kitty()           { [ -x /opt/kitty.app/bin/kitty ]; }
installed_source_swayimg()         { [ -x /usr/local/bin/swayimg ]; }
installed_source_zen()             { [ -x "$ZEN_TARBALL_DIR/zen-bin" ]; }
