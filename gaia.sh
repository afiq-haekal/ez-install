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
        print_color $YELLOW "Updating environment..."
        source ~/.bashrc
        export PATH="$HOME/gaianet/bin:$PATH"
        print_color $GREEN "Environment updated! You can now use GaiaNet"
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

# Function to initialize node
init_node() {
    if ! command -v gaianet &> /dev/null; then
        print_color $RED "GaiaNet not found. Please install it first."
        return 1
    fi

    # Check for both nodeid and model file
    if [ -f "$HOME/gaianet/nodeid.json" ] && [ -f "$HOME/gaianet/models/Llama-3.2-3B-Instruct-Q5_K_M.gguf" ]; then
        print_color $YELLOW "Node is already initialized with required model"
        return 0
    fi

    print_color $YELLOW "Initializing node..."
    gaianet init
    if [ $? -eq 0 ]; then
        print_color $GREEN "Node initialized successfully"
    else
        print_color $RED "Node initialization failed"
        return 1
    fi
}

# Function to start node
start_node() {
    if ! command -v gaianet &> /dev/null; then
        print_color $RED "GaiaNet not found. Please install it first."
        return 1
    fi

    if [ ! -f "$HOME/gaianet/nodeid.json" ]; then
        print_color $RED "Node is not initialized. Please initialize first (option 4)."
        return 1
    fi

    print_color $YELLOW "Starting node..."
    nohup gaianet start > gaianet.log 2>&1 &
    sleep 2

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
    if ! command -v gaianet &> /dev/null; then
        print_color $RED "GaiaNet not found. Please install it first."
        return 1
    fi

    if pgrep -f "gaianet start" > /dev/null; then
        print_color $YELLOW "Stopping node..."
        gaianet stop
        print_color $GREEN "Node stopped"
    else
        print_color $RED "No running node found"
    fi
}

# Function to show node info
show_info() {
    if ! command -v gaianet &> /dev/null; then
        print_color $RED "GaiaNet not found. Please install it first."
        return 1
    fi

    if [ ! -f "$HOME/gaianet/nodeid.json" ]; then
        print_color $RED "Node is not initialized. Please initialize first (option 4)."
        return 1
    fi

    gaianet info
}

# Main menu
while true; do
    clear
    print_color $GREEN "=== GaiaNet Node Manager ==="
    echo "1. Install GaiaNet"
    echo "2. Update GaiaNet"
    echo "3. Uninstall GaiaNet"
    echo "4. Initialize Node"
    echo "5. Start Node"
    echo "6. Stop Node"
    echo "7. Show Node Info"
    echo "8. Exit"
    echo
    
    read -p "Enter your choice (1-8): " choice
    
    case $choice in
        1) install_latest ;;
        2) update_installation ;;
        3) uninstall_gaianet ;;
        4) init_node ;;
        5) start_node ;;
        6) stop_node ;;
        7) show_info ;;
        8) print_color $GREEN "Goodbye!"; exit 0 ;;
        *) print_color $RED "Invalid option. Please try again." ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read
done
