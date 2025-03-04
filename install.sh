#!/bin/bash

if ! command -v gum &>/dev/null; then
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

print_success_message() {
    local message=$1

    if $HAS_GUM; then
        gum style \
            --foreground 76 --border-foreground 76 --border normal \
            --align center --width 40 --margin "0 2" --padding "0 1" \
            "✓ $message"
    else
        echo -e "\e[1;32m==>\e[0m \e[1mSuccess: $message\e[0m"
    fi
}

print_error_message() {
    local message=$1

    if $HAS_GUM; then
        gum style \
            --foreground 196 --border-foreground 196 --border normal \
            --align center --width 40 --margin "0 2" --padding "0 1" \
            "✗ $message"
    else
        echo -e "\e[1;31m==>\e[0m \e[1mError: $message\e[0m"
    fi
}

check_success() {
    if [ $? -eq 0 ]; then
        print_success_message "$1"
    else
        print_error_message "$1"
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
        y | Y) return 0 ;;
        *)
            echo ":: Skipping: $message"
            return 1
            ;;
        esac
    fi
}

create_symlink() {
    local source=$1
    local target=$2
    
    if [ -e "$target" ]; then
        if [ -L "$target" ]; then
            echo ":: Symlink already exists, removing..."
            rm "$target"
        else
            echo ":: File/directory already exists, backing up..."
            mv "$target" "${target}.bak"
        fi
    fi
    
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    check_success "Created symlink from $source to $target"
}

print_styled_message "System Update"
if confirm_action "update the system"; then
    execute_command sudo pacman -Syu --noconfirm
fi

if ! command -v yay &>/dev/null; then
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

print_styled_message "System Update"
if confirm_action "update the system"; then
    execute_command sudo pacman -Syu --noconfirm
fi

print_styled_message "Installing additional packages via pacman"
if [ -f "$(pwd)/pacman_packages.txt" ]; then
    PACMAN_PACKAGES=($(cat "$(pwd)/pacman_packages.txt" | grep -v "^#" | tr '\n' ' '))
    if [ ${#PACMAN_PACKAGES[@]} -gt 0 ]; then
        if confirm_action "install additional packages via pacman"; then
            execute_command sudo pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"
        fi
    else
        echo ":: No packages found in pacman_packages.txt, skipping..."
    fi
else
    echo ":: pacman_packages.txt not found, skipping installation of additional pacman packages..."
fi

print_styled_message "Installing additional packages via yay"
if [ -f "$(pwd)/yay_packages.txt" ]; then
    YAY_PACKAGES=($(cat "$(pwd)/yay_packages.txt" | grep -v "^#" | tr '\n' ' '))
    if [ ${#YAY_PACKAGES[@]} -gt 0 ]; then
        if confirm_action "install additional packages via yay"; then
            execute_command yay -S --noconfirm "${YAY_PACKAGES[@]}"
        fi
    else
        echo ":: No packages found in yay_packages.txt, skipping..."
    fi
else
    echo ":: yay_packages.txt not found, skipping installation of additional yay packages..."
fi

# RustDesk installation
print_styled_message "Installing RustDesk"
if confirm_action "install RustDesk version 1.3.7"; then
    mkdir -p ~/Downloads/apps
    cd ~/Downloads/apps
    
    print_styled_message "Downloading RustDesk 1.3.7"
    RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.3.7/rustdesk-1.3.7-0-x86_64.pkg.tar.zst"
    RUSTDESK_PKG="rustdesk-1.3.7-0-x86_64.pkg.tar.zst"
    
    execute_command wget -O "$RUSTDESK_PKG" "$RUSTDESK_URL"
    
    print_styled_message "Installing RustDesk package"
    execute_command sudo pacman -U --noconfirm "$RUSTDESK_PKG"
    
    print_success_message "RustDesk 1.3.7 installed successfully"
    
    cd - > /dev/null # Return to original directory
fi

# Configuring GTK
print_styled_message "Configuring GTK (removing window control buttons)"
if confirm_action "configure GTK"; then
    execute_command gsettings set org.gnome.desktop.wm.preferences button-layout ':'
fi

# Configuring SDDM
print_styled_message "Configuring SDDM"
if confirm_action "copy SDDM theme"; then
    execute_command sudo cp -r $(pwd)/sddm/corners /usr/share/sddm/themes/
fi

print_styled_message "Configuring SDDM config"
if confirm_action "configure SDDM config"; then
    execute_command sudo cp $(pwd)/sddm/default.conf /usr/lib/sddm/sddm.conf.d/default.conf
fi

print_styled_message "Enabling SDDM"
if confirm_action "enable SDDM"; then
    execute_command sudo systemctl enable sddm
fi

# Enabling Bluetooth service
print_styled_message "Enabling Bluetooth service"
if confirm_action "enable Bluetooth service"; then
    execute_command sudo systemctl enable bluetooth.service
    print_success_message "Bluetooth service enabled"
fi

# Enable hyprpm
print_styled_message "Enable hyprpm"
if confirm_action "enable hyprpm"; then
    execute_command hyprpm update -s -v
    print_success_message "Enable hyprpm"
fi

# Application configurations
print_styled_message "Configuring applications"

# Thunar configuration
if command -v thunar &>/dev/null; then
    print_styled_message "Configuring Thunar"
    if confirm_action "configure Thunar"; then
        mkdir -p ~/.config/Thunar
        create_symlink "$(pwd)/thunar/uca.xml" "$HOME/.config/Thunar/uca.xml"
    fi
fi

# Zoom configuration
if command -v zoom &>/dev/null || [ -f ~/.config/zoomus.conf ]; then
    print_styled_message "Configuring Zoom"
    if confirm_action "configure Zoom for Wayland"; then
        if [ -f ~/.config/zoomus.conf ]; then
            if grep -q "enableWaylandShare" ~/.config/zoomus.conf; then
                sed -i 's/enableWaylandShare=.*/enableWaylandShare=true/' ~/.config/zoomus.conf
            else
                echo "enableWaylandShare=true" >> ~/.config/zoomus.conf
            fi
        else
            echo "enableWaylandShare=true" > ~/.config/zoomus.conf
        fi
        print_success_message "Zoom configured for Wayland"
    fi
fi

# Wofi configuration
if command -v wofi &>/dev/null; then
    print_styled_message "Configuring Wofi"
    if confirm_action "configure Wofi"; then
        mkdir -p ~/.config/wofi
        create_symlink "$(pwd)/wofi" "$HOME/.config/wofi"
    fi
fi

# nwg-displays configuration
if command -v nwg-displays &>/dev/null; then
    print_styled_message "Configuring nwg-displays"
    if confirm_action "configure nwg-displays"; then
        # Find Python version
        PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        NWG_DISPLAYS_PATH="/usr/lib/python${PYTHON_VERSION}/site-packages/nwg_displays/main.py"
        
        if [ -f "$NWG_DISPLAYS_PATH" ]; then
            print_styled_message "Modifying nwg-displays configuration"
            sudo sed -i 's|hypr_config_dir = os.path.join(get_config_home(), "hypr")|hypr_config_dir = os.path.join(get_config_home(), "hypr/conf")|g' "$NWG_DISPLAYS_PATH"
            print_success_message "nwg-displays configured"
        else
            print_error_message "nwg-displays main.py not found at $NWG_DISPLAYS_PATH"
        fi
    fi
fi

# wlogout configuration
if command -v wlogout &>/dev/null; then
    print_styled_message "Configuring wlogout"
    if confirm_action "configure wlogout"; then
        mkdir -p ~/.config/wlogout
        create_symlink "$(pwd)/wlogout" "$HOME/.config/wlogout"
    fi
fi

# kitty configuration
if command -v kitty &>/dev/null; then
    print_styled_message "Configuring kitty"
    if confirm_action "configure kitty"; then
        mkdir -p ~/.config/kitty
        create_symlink "$(pwd)/kitty" "$HOME/.config/kitty"
    fi
fi

# hyprswitch configuration
if [ -d "$(pwd)/hyprswitch" ]; then
    print_styled_message "Configuring hyprswitch"
    if confirm_action "configure hyprswitch"; then
        mkdir -p ~/.config/hypr
        create_symlink "$(pwd)/hyprswitch" "$HOME/.config/hyprswitch"
    fi
fi

# hypapnel configuration
if [ -d "$(pwd)/hyprpanel" ]; then
    print_styled_message "Configuring hyprpanel"
    if confirm_action "configure hyprpanel"; then
        mkdir -p ~/.config/hypr
        create_symlink "$(pwd)/hyprpanel" "$HOME/.config/hyprpanel"
    fi
fi

# Java configuration
if command -v java &>/dev/null; then
    print_styled_message "Configuring Java"
    if confirm_action "configure Java environment"; then
        if [ -d "/usr/lib/jvm/java-21-openjdk" ]; then
            echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk' >> ~/.bashrc
            echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk' >> ~/.zshrc
            if [ -d ~/.config/fish ]; then
                mkdir -p ~/.config/fish
                echo 'set -x JAVA_HOME /usr/lib/jvm/java-21-openjdk' >> ~/.config/fish/config.fish
            fi
            print_success_message "Java environment configured"
        else
            print_error_message "Java 21 OpenJDK not found"
        fi
    fi
fi

# fastfetch configuration
if command -v fastfetch &>/dev/null; then
    print_styled_message "Configuring fastfetch"
    if confirm_action "configure fastfetch"; then
        mkdir -p ~/.config/fastfetch
        create_symlink "$(pwd)/fastfetch" "$HOME/.config/fastfetch"
    fi
fi

# fish configuration
if command -v fish &>/dev/null; then
    print_styled_message "Configuring fish"
    if confirm_action "configure fish"; then
        mkdir -p ~/.config/fish
        create_symlink "$(pwd)/fish" "$HOME/.config/fish"
    fi
fi

# Git configuration
print_styled_message "Configuring Git"
if confirm_action "configure Git"; then
    execute_command git config --global user.name "Irrisorr"
    execute_command git config --global user.email "zakharkevichg@gmail.com"
    print_success_message "Polkit agent started"
fi

# hyprpaper configuration
if command -v hyprpaper &>/dev/null; then
    print_styled_message "Configuring hyprpaper"
    if confirm_action "configure hyprpaper"; then
        mkdir -p ~/.config/hypr
        create_symlink "$(pwd)/hyprpaper" "$HOME/.config/hyprpaper"
        
        print_styled_message "Creating wallpaper changer desktop entry"
        if confirm_action "create wallpaper changer desktop entry"; then
            DESKTOP_FILE="/usr/share/applications/Wallpaper changer.desktop"
            
            sudo tee "$DESKTOP_FILE" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Hyprpaper Wallpaper Setter
Comment=Приложение для установки обоев через Hyprpaper
Exec=python3 $HOME/.config/hypr/scripts/change-wallpaper.py
Icon=$HOME/Desktop/icon EnjAction.png
Terminal=false
Categories=Utility;
EOF
            sudo chmod ugo+x "$DESKTOP_FILE"
            print_success_message "Wallpaper changer desktop entry created"
        fi
    fi
fi

# hyprlock configuration
if command -v hyprlock &>/dev/null; then
    print_styled_message "Configuring hyprlock"
    if confirm_action "configure hyprlock"; then
        mkdir -p ~/.config/hypr
        create_symlink "$(pwd)/hyprlock" "$HOME/.config/hyprlock"
    fi
fi

# Update user directories
print_styled_message "Updating user directories"
if confirm_action "update user directories"; then
    execute_command xdg-user-dirs-update
    print_styled_message "You can edit directory names in ~/.config/user-dirs.dirs"
fi

# Start polkit agent
print_styled_message "Starting polkit agent"
if confirm_action "start polkit agent"; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
    print_success_message "Polkit agent started"
fi

# Function to convert Russian XDG directories to English
convert_xdg_dirs_to_english() {
    print_styled_message "Converting XDG user directories to English..."
    if confirm_action "Do you want to convert XDG user directories to English?"; then

        # Set English XDG directories
        cat > ~/.config/user-dirs.dirs << EOL
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOL

        # Create English directories
        mkdir -p ~/Desktop ~/Downloads ~/Templates ~/Public ~/Documents ~/Music ~/Pictures ~/Videos

        # Move files from Russian to English directories if they exist
        mv -n "$HOME/Рабочий стол"/* "$HOME/Desktop" 2>/dev/null || true
        mv -n "$HOME/Загрузки"/* "$HOME/Downloads" 2>/dev/null || true
        mv -n "$HOME/Шаблоны"/* "$HOME/Templates" 2>/dev/null || true
        mv -n "$HOME/Общедоступные"/* "$HOME/Public" 2>/dev/null || true
        mv -n "$HOME/Документы"/* "$HOME/Documents" 2>/dev/null || true
        mv -n "$HOME/Музыка"/* "$HOME/Music" 2>/dev/null || true
        mv -n "$HOME/Изображения"/* "$HOME/Pictures" 2>/dev/null || true
        mv -n "$HOME/Видео"/* "$HOME/Videos" 2>/dev/null || true

        # Remove empty Russian directories
        rmdir "$HOME/Рабочий стол" "$HOME/Загрузки" "$HOME/Шаблоны" "$HOME/Общедоступные" \
              "$HOME/Документы" "$HOME/Музыка" "$HOME/Изображения" "$HOME/Видео" 2>/dev/null || true

        # Create symbolic link in HyprDots
        ln -sf ~/.config/user-dirs.dirs "$INSTALL_DIR/user-dirs.dirs"
        check_success "XDG user directories converted to English successfully!"
    fi
}

# Function to setup mimeinfo.cache
setup_mimeinfo_cache() {
    print_styled_message "Setting up mimeinfo.cache..."
    if confirm_action "Do you want to setup mimeinfo.cache with Zen Browser as default PDF viewer?"; then
        # Create a copy of mimeinfo.cache
        sudo cp /usr/share/applications/mimeinfo.cache "$INSTALL_DIR/mimeinfo.cache"
        
        # Update PDF association
        sed -i 's|application/pdf=.*|application/pdf=zen.desktop|' "$INSTALL_DIR/mimeinfo.cache"
        check_success "mimeinfo.cache setup completed!"
    fi
}

# Add new functions to main installation process
convert_xdg_dirs_to_english
setup_mimeinfo_cache

# Make post-installation script executable
if [ -f "$(pwd)/post_install.sh" ]; then
    print_styled_message "Making post-installation script executable"
    chmod +x "$(pwd)/post_install.sh"
    print_success_message "Post-installation script is ready to use"
    echo ":: After reboot, run ./post_install.sh to complete additional setup tasks"
fi

print_styled_message "Installation complete! Restart your computer for changes to take effect."
