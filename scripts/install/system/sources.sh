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


# clipse has no Debian package, no PPA, no snap and no release binaries, so it
# is built from source. The upstream Makefile's wayland target is
# `CGO_ENABLED=0 go build -tags wayland`; go install takes the same tag and
# skips the clone, so that is what runs here.
#
# NOTE: this does not update with the system. Re-run the step to upgrade.
install_source_clipse() {
  command -v go &>/dev/null || pkg_install golang-go || return 1

  CGO_ENABLED=0 go install -tags wayland github.com/savedra1/clipse@latest || return 1

  local gobin="${GOBIN:-$(go env GOPATH)/bin}"
  [ -x "$gobin/clipse" ] || { print_error_message "clipse not found in $gobin"; return 1; }

  echo ":: clipse installed to $gobin — make sure that directory is on your PATH"
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
