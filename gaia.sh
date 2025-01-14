#!/bin/bash

# Colors for better visual feedback
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored text
print_color() {
    local color=$1
    local text=$2
    echo -e "${color}${text}${NC}"
}

# Function to install latest version
install_latest() {
    print_color $YELLOW "Installing latest version of GaiaNet..."
    curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash
    if [ $? -eq 0 ]; then
        print_color $GREEN "Installation completed successfully!"
        print_color $YELLOW "Please restart your terminal to use GaiaNet"
    else
        print_color $RED "Installation failed!"
    fi
}

# Function to update installation
update_installation() {
    print_color $YELLOW "Updating GaiaNet..."
    curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash -s -- --upgrade
    if [ $? -eq 0 ]; then
        print_color $GREEN "Update completed successfully!"
    else
        print_color $RED "Update failed!"
    fi
}

# Function to uninstall
uninstall_gaianet() {
    read -p "Are you sure you want to uninstall GaiaNet? (y/n): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        print_color $YELLOW "Uninstalling GaiaNet..."
        curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/uninstall.sh' | bash
        if [ $? -eq 0 ]; then
            print_color $GREEN "Uninstallation completed successfully!"
        else
            print_color $RED "Uninstallation failed!"
        fi
    fi
}

# Function to manage node
manage_node() {
    # Check if gaianet is in PATH
    if ! command -v gaianet &> /dev/null; then
        print_color $RED "GaiaNet not found. Please install it first."
        return 1
    fi

    # Check if node is already initialized
    if [ ! -f "$HOME/gaianet/nodeid.json" ]; then
        print_color $YELLOW "Initializing node..."
        gaianet init
    fi

    # Start node
    print_color $YELLOW "Starting node..."
    nohup gaianet start > gaianet.log 2>&1 &
    sleep 2

    # Check if node started successfully
    if pgrep -f "gaianet start" > /dev/null; then
        print_color $GREEN "Node started successfully"
        gaianet info
    else
        print_color $RED "Failed to start node"
        tail -n 5 gaianet.log
    fi
}

# Function to stop node
stop_node() {
    if pgrep -f "gaianet start" > /dev/null; then
        print_color $YELLOW "Stopping node..."
        gaianet stop
        print_color $GREEN "Node stopped"
    else
        print_color $RED "No running node found"
    fi
}

# Main menu
while true; do
    clear
    print_color $GREEN "=== GaiaNet Node Manager ==="
    echo "1. Install GaiaNet"
    echo "2. Update GaiaNet"
    echo "3. Uninstall GaiaNet"
    echo "4. Start Node"
    echo "5. Stop Node"
    echo "6. Show Node Info"
    echo "7. Exit"
    echo
    
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1) install_latest ;;
        2) update_installation ;;
        3) uninstall_gaianet ;;
        4) manage_node ;;
        5) stop_node ;;
        6) 
            if command -v gaianet &> /dev/null; then
                gaianet info
            else
                print_color $RED "GaiaNet not found. Please install it first."
            fi
            ;;
        7) print_color $GREEN "Goodbye!"; exit 0 ;;
        *) print_color $RED "Invalid option. Please try again." ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read
done
