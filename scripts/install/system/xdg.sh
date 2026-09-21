#!/bin/bash
. "$HOME/Dotfiles/scripts/lib/common.sh"

# Menu guard: xdg-user-dirs-update
update_user_dirs() {
  execute_command "Update user directories" "xdg-user-dirs-update"
}

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
  if ! confirm_action "Do you want to convert XDG user directories to English?"; then
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
