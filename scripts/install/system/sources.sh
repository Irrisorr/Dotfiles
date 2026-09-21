#!/bin/bash
#
# Escape hatch for packages that no generic backend can express — anything
# needing a clone, a build, or files laid out by hand.
#
# Reach for this LAST. apt / aur / flatpak / snap / url / ppa cover nearly
# everything, and they need no code at all — just a tail in packages.txt.
#
# Contract:  packages.txt "<distro>:source=<name>"  →  install_source_<name>
#
#   packages.txt:  dms-shell-bin  ubuntu:source=dms
#   here:          install_source_dms() { ... }
#
# Return 0 on success, non-zero on failure — the installer collects failures
# and reports them at the end instead of aborting the whole run.

. "$HOME/Dotfiles/scripts/lib/common.sh"

# No custom installers are needed yet. Add them here as they come up.
