#!/bin/bash

. $HOME/Dotfiles/install_scripts/functions.sh
. $HOME/Dotfiles/scripts/scripts.sh


while true; do
  menu_first_level
  menu_second_level
  if [ $? -ne 3 ]; then
    break
  fi
done