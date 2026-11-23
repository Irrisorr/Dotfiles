#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: xdg-user-dirs-update
# About: Creates the home folders (Desktop, Downloads, Documents, ...) and registers them for apps.
update_user_dirs() {
  execute_command "Update user directories" "xdg-user-dirs-update"
}

# About: Renames Russian home folders (Загрузки, Документы, ...) to English and moves their files over.
convert_xdg_dirs() {
  local russian_dirs=("$HOME/Рабочий стол" "$HOME/Загрузки" "$HOME/Шаблоны" "$HOME/Общедоступные" "$HOME/Документы" "$HOME/Музыка" "$HOME/Изображения" "$HOME/Видео")
  local russian_exists=false

  for dir in "${russian_dirs[@]}"; do
    if [ -d "$dir" ]; then
      russian_exists=true
      break
    fi
  done

  if [ "$russian_exists" = false ]; then
    print_error_message "There are no Russian XDG user directories to convert"
    return 1
  fi

  print_styled_message "Converting Russian XDG user directories to English"
  if ! confirm_step "convert XDG user directories to English"; then
    return 1
  fi

  cat >$HOME/.config/user-dirs.dirs <<EOL
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOL

  mkdir -p $HOME/Desktop $HOME/Downloads $HOME/Templates $HOME/Public $HOME/Documents $HOME/Music $HOME/Pictures $HOME/Videos
  mv -n "$HOME/Рабочий стол"/* "$HOME/Desktop" 2>/dev/null || true
  mv -n "$HOME/Загрузки"/* "$HOME/Downloads" 2>/dev/null || true
  mv -n "$HOME/Шаблоны"/* "$HOME/Templates" 2>/dev/null || true
  mv -n "$HOME/Общедоступные"/* "$HOME/Public" 2>/dev/null || true
  mv -n "$HOME/Документы"/* "$HOME/Documents" 2>/dev/null || true
  mv -n "$HOME/Музыка"/* "$HOME/Music" 2>/dev/null || true
  mv -n "$HOME/Изображения"/* "$HOME/Pictures" 2>/dev/null || true
  mv -n "$HOME/Видео"/* "$HOME/Videos" 2>/dev/null || true

  rmdir "$HOME/Рабочий стол" "$HOME/Загрузки" "$HOME/Шаблоны" "$HOME/Общедоступные" \
    "$HOME/Документы" "$HOME/Музыка" "$HOME/Изображения" "$HOME/Видео" 2>/dev/null || true

  check_success "XDG user directories converted to English successfully!"
}

# Menu guard: test:has_vault_documents
# ~/Documents becomes a link to the vault's documents folder (VAULT_DOCUMENTS,
# scripts/lib/paths.sh). A real ~/Documents is merged in first; a file that
# exists in both with other content stops it, nothing gets overwritten.
# About: Makes ~/Documents a link to the documents in the Obsidian vault, so they sync with the phone.
link_documents_to_vault() {
  local docs="$HOME/Documents" rel=${VAULT_DOCUMENTS#"$HOME"/} clash
  if [ "$(readlink "$docs")" = "$rel" ] || [ "$(readlink "$docs")" = "$VAULT_DOCUMENTS" ]; then
    print_success_message "~/Documents already links to $rel"
    return 0
  fi
  if [ -L "$docs" ]; then
    print_error_message "~/Documents is a link to $(readlink "$docs"), leaving it"
    return 2
  fi
  confirm_step "make ~/Documents a link to $rel (its files move there)" || return 1
  if [ -d "$docs" ]; then
    clash=$(cd "$docs" && find . -type f -print0 | while IFS= read -r -d '' f; do
      [ -e "$VAULT_DOCUMENTS/$f" ] && ! cmp -s "$f" "$VAULT_DOCUMENTS/$f" && echo "  ${f#./}"
    done)
    if [ -n "$clash" ]; then
      print_error_message "Same name, other content in ~/Documents and $rel:"
      echo "$clash"
      return 2
    fi
    cp -a -n "$docs/." "$VAULT_DOCUMENTS/" || return 2
    if command -v gio &>/dev/null; then
      gio trash "$docs" || return 2
    else
      mv "$docs" "$docs.old-$(date +%F)" || return 2
    fi
  fi
  ln -s "$rel" "$docs"
  check_success "~/Documents -> $rel"
}
