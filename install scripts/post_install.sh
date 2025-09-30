#!/bin/bash

# Check if gum is installed, install if missing
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

# Post-installation tasks
print_styled_message "Post-Installation Tasks"

# iMe Desktop installation
print_styled_message "Installing iMe Desktop"
if confirm_action "install iMe Desktop"; then
    mkdir -p ~/Downloads/apps
    cd ~/Downloads/apps
    
    print_styled_message "Downloading iMe Desktop"
    echo ":: Opening browser to download iMe Desktop..."
    xdg-open "https://imem.app/download/desktop/linux"
    
    print_styled_message "Waiting for download"
    echo ":: Please download the iMe Desktop package from the browser."
    echo ":: After downloading, press Enter to continue..."
    read -p "Press Enter when download is complete: " dummy
    
    # Find the most recent iMe download
    IME_ARCHIVE=$(find ~/Downloads -name "iMe*.tar.xz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
    
    if [ -z "$IME_ARCHIVE" ]; then
        print_error_message "iMe Desktop archive not found in Downloads folder"
        echo ":: Please download iMe Desktop manually and extract it to ~/Downloads/apps/iMeDesktop"
    else
        print_styled_message "Extracting iMe Desktop"
        execute_command tar -xf "$IME_ARCHIVE" -C ~/Downloads/apps
        
        if [ -d ~/Downloads/apps/iMeDesktop ]; then
            print_styled_message "Running iMe Desktop to create desktop file"
            echo ":: Starting iMe Desktop, it will be terminated after 2 seconds..."
            cd ~/Downloads/apps/iMeDesktop
            ./iMe &
            IME_PID=$!
            sleep 2
            kill $IME_PID 2>/dev/null
            print_success_message "iMe Desktop desktop file created"
        else
            print_error_message "iMe Desktop directory not found after extraction"
        fi
    fi
    
    cd - > /dev/null # Return to original directory
fi

# Installing Hyprland plugins
print_styled_message "Installing Hyprland plugins"

# hypr-dynamic-cursors plugin
print_styled_message "Installing hypr-dynamic-cursors plugin"
if confirm_action "install hypr-dynamic-cursors plugin"; then
    print_styled_message "Adding hypr-dynamic-cursors plugin"
    execute_command hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
    
    print_styled_message "Enabling hypr-dynamic-cursors plugin"
    execute_command hyprpm enable dynamic-cursors
    
    print_success_message "hypr-dynamic-cursors plugin installed and enabled"
fi

#Auth github via Github-cli
print_styled_message "Auth github via Github-cli (Browser required)"
if confirm_action "auth github via Github-cli"; then
    execute_command gh auth login
    print_success_message "Github-cli auth success"
fi

print_styled_message "Post-installation tasks complete!" 