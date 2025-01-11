#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file location
LOG_FILE="/var/log/network3-node.log"

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Function to display the menu
show_menu() {
    clear
    echo -e "${GREEN}=== Network3 Node Manager ===${NC}"
    echo "1. Download and Setup Node"
    echo "2. Start Node"
    echo "3. Stop Node"
    echo "4. View Dashboard URL"
    echo "5. Get API Key"
    echo "6. View Logs"
    echo "7. Exit"
    echo
}

# Function to download and setup node
setup_node() {
    echo -e "${YELLOW}Starting node setup...${NC}"
    
    # Update package list
    echo "Updating package list..."
    apt-get update

    # Check and install required packages
    for pkg in wget net-tools; do
        if ! command -v $pkg &> /dev/null; then
            echo "Installing $pkg..."
            apt-get install -y $pkg
        fi
    done
    
    # Download the node package
    wget https://network3.io/ubuntu-node-v2.1.1.tar.gz
    
    # Extract the package
    tar -xf ubuntu-node-v2.1.1.tar.gz
    
    # Change directory and set permissions
    cd ubuntu-node
    chmod +x manager.sh
    
    echo -e "${GREEN}Node setup completed!${NC}"
}

# Function to start the node
start_node() {
    if [ -f "manager.sh" ]; then
        echo -e "${YELLOW}Starting Network3 node with nohup...${NC}"
        
        # Set proper umask before starting
        umask 077
        
        # Create logs directory if it doesn't exist
        mkdir -p logs
        
        # Start the node with nohup and redirect output to log file
        nohup bash manager.sh up > logs/node.log 2>&1 &
        
        # Wait a moment for the node to start
        sleep 5
        
        echo -e "${GREEN}Node started in background! View logs with option 6${NC}"
    else
        echo -e "${RED}Error: manager.sh not found. Please run setup first.${NC}"
    fi
}

# Function to stop the node
stop_node() {
    if [ -f "manager.sh" ]; then
        echo -e "${YELLOW}Stopping Network3 node...${NC}"
        bash manager.sh down
        echo -e "${GREEN}Node stopped successfully!${NC}"
    else
        echo -e "${RED}Error: manager.sh not found. Please run setup first.${NC}"
    fi
}

# Function to display dashboard URL
show_dashboard() {
    echo -e "${GREEN}Dashboard URLs:${NC}"
    echo "Local access: https://account.network3.ai/main"
    
    # Get IP address
    IP=$(hostname -I | awk '{print $1}')
    echo -e "Remote access: https://account.network3.ai/main?o=${IP}:8080"
}

# Function to get API key
get_api_key() {
    if [ -f "manager.sh" ]; then
        echo -e "${YELLOW}Retrieving API key...${NC}"
        bash manager.sh key
    else
        echo -e "${RED}Error: manager.sh not found. Please run setup first.${NC}"
    fi
}

# Function to view logs
view_logs() {
    if [ -f "logs/node.log" ]; then
        echo -e "${GREEN}Last 50 lines of node log:${NC}"
        tail -n 50 logs/node.log
    else
        echo -e "${RED}No log file found in logs/node.log${NC}"
    fi
}

# Main program loop
while true; do
    show_menu
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            check_root
            setup_node
            ;;
        2)
            check_root
            start_node
            ;;
        3)
            check_root
            stop_node
            ;;
        4)
            show_dashboard
            ;;
        5)
            check_root
            get_api_key
            ;;
        6)
            view_logs
            ;;
        7)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
