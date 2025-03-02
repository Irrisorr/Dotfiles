#!/bin/bash

if ! command -v gum &> /dev/null; then
    echo ":: Installing gum for beautiful output..."
    sudo pacman -S --noconfirm gum || {
        echo ":: Failed to install gum, continuing without it..."
        HAS_GUM=false
    }
else
    HAS_GUM=true
fi

print_styled_message() {
    local message=$1
    
    if $HAS_GUM; then
        gum style \
            --foreground 212 --border-foreground 212 --border normal \
            --align center --width 50 --margin "0 2" --padding "1 2" \
            "$message"
    else
        echo -e "\e[1;34m==>\e[0m \e[1m$message\e[0m"
    fi
}

check_success() {
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m==>\e[0m \e[1mSuccess: $1\e[0m"
    else
        echo -e "\e[1;31m==>\e[0m \e[1mError: $1\e[0m"
        exit 1
    fi
}

execute_command() {
    "$@"
    check_success "Command execution: $*"
}

confirm_action() {
    local message=$1
    
    if $HAS_GUM; then
        if gum confirm "Do you want to $message?"; then
            return 0
        else
            echo ":: Skipping: $message"
            return 1
        fi
    else
        read -p "Do you want to $message? (y/n): " choice
        case "$choice" in
            y|Y ) return 0;;
            * ) echo ":: Skipping: $message"; return 1;;
        esac
    fi
}

print_styled_message "System Update"
if confirm_action "update the system"; then
    execute_command sudo pacman -Syu --noconfirm
fi

if ! command -v yay &> /dev/null; then
    print_styled_message "Installing yay"
    if confirm_action "install yay"; then
        git clone https://aur.archlinux.org/yay.git
        check_success "Cloning yay repository"
        
        cd yay
        makepkg -si --noconfirm
        check_success "Installing yay"
        cd ..
        rm -rf yay
    fi
else
    print_styled_message "yay is already installed, skipping..."
fi

print_styled_message "Installing Hyprland"
if confirm_action "install Hyprland"; then
    execute_command sudo pacman -S --noconfirm hyprland
fi

print_styled_message "Creating symbolic link to Hyprland configuration"
if confirm_action "create symbolic link to Hyprland configuration"; then
    mkdir -p ~/.config
    execute_command ln -sf $(pwd)/hypr ~/.config/hypr
fi

print_styled_message "Installing themes"
if confirm_action "install GTK theme"; then
    execute_command yay -S --noconfirm graphite-gtk-theme
fi

if confirm_action "install QT themes"; then
    execute_command yay -S --noconfirm adwaita-qt5 adwaita-qt6
fi

print_styled_message "Installing cursors"
if confirm_action "install cursor theme"; then
    execute_command yay -S --noconfirm bibata-cursor-theme
fi

print_styled_message "Installing icons"
if confirm_action "install icon theme"; then
    execute_command sudo pacman -S --noconfirm papirus-icon-theme
fi

print_styled_message "Installing fonts"
if confirm_action "install fonts"; then
    execute_command sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd
fi

print_styled_message "Installing additional packages via pacman"
PACMAN_PACKAGES=(
    "sddm"
    "qt5-graphicaleffects"
    "qt5-svg"
    "qt5-quickcontrols2"
)

if confirm_action "install additional packages via pacman"; then
    execute_command sudo pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"
fi

print_styled_message "Installing additional packages via yay"
YAY_PACKAGES=(
    "visual-studio-code-bin"
    "spotify"
)

if [ ${#YAY_PACKAGES[@]} -gt 0 ]; then
    if confirm_action "install additional packages via yay"; then
        execute_command yay -S --noconfirm "${YAY_PACKAGES[@]}"
    fi
else
    echo ":: List of packages to install via yay is empty, skipping..."
fi

print_styled_message "Configuring GTK (removing window control buttons)"
if confirm_action "configure GTK"; then
    execute_command gsettings set org.gnome.desktop.wm.preferences button-layout ':'
fi

print_styled_message "Configuring SDDM"
if confirm_action "copy SDDM theme"; then
    execute_command sudo cp -r $(pwd)/sddm /usr/share/sddm/themes/
fi

print_styled_message "Configuring SDDM config"
if confirm_action "configure SDDM config"; then
    execute_command sudo cp $(pwd)/sddm.conf /usr/lib/sddm/sddm.conf.d/default.conf
fi

print_styled_message "Enabling SDDM"
if confirm_action "enable SDDM"; then
    execute_command sudo systemctl enable sddm
fi

print_styled_message "Installation complete! Restart your computer for changes to take effect." 