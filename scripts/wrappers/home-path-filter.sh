#!/bin/bash
#
# Git filter for configs that only take absolute paths (see .gitattributes):
# dfiles/bookmarks.json — Dux files drops a bookmark whose path isn't absolute,
# so "~" can't be used there. clean writes this user's home as @HOME@ (and the
# home bookmark's label, the user name, as @USER@), smudge puts them back, so
# the repo holds no user name and every machine gets its own home.
#
#   home-path-filter.sh clean|smudge    (stdin → stdout, run by git)
#
# Registered per clone by the installer's "Dux files config" step, which also
# smudges a file checked out before that.

export FILTER_USER=${USER:-$(id -un)}
case $1 in
  clean)  exec perl -pe 's/\Q$ENV{HOME}\E(?=["\/])/\@HOME\@/g; s/("label":\s*")\Q$ENV{FILTER_USER}\E"/$1\@USER\@"/g' ;;
  smudge) exec perl -pe 's/\@HOME\@/$ENV{HOME}/g; s/\@USER\@/$ENV{FILTER_USER}/g' ;;
  *) exit 2 ;;
esac
