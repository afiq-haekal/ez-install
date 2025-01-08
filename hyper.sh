#!/bin/bash

# Set log file locations
INSTALL_LOG="$HOME/hyperspace_install.log"
RUNTIME_LOG="$HOME/hyperspace_runtime.log"

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}"
        return 1
    fi
    return 0
}

# Function to verify CUDA installation
verify_cuda() {
    echo "Verifying CUDA installation..."
    
    # Check nvidia-smi
    if ! nvidia-smi &>/dev/null; then
        echo -e "${RED}Error: nvidia-smi not working${NC}"
        return 1
    fi
    
    # Check nvcc
    if ! nvcc --version &>/dev/null; then
        echo -e "${RED}Error: nvcc not found in PATH${NC}"
        return 1
    fi
    
    echo -e "${GREEN}CUDA verification successful:${NC}"
    nvidia-smi
    nvcc --version
    return 0
}

# Function to install Hyperspace
install_hyperspace() {
    echo "Starting installation process..." | tee -a "$INSTALL_LOG"

    # Check if NVIDIA GPU is present
    if ! lspci | grep -i nvidia > /dev/null; then
        echo -e "${RED}Error: No NVIDIA GPU detected${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi

    # Check if CUDA is already installed
    if verify_cuda; then
        echo -e "${GREEN}CUDA is already installed and working properly.${NC}" | tee -a "$INSTALL_LOG"
    else
        echo -e "${RED}CUDA verification failed. Please install CUDA first.${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi

    # Install Hyperspace
    echo "Installing Hyperspace..." | tee -a "$INSTALL_LOG"
    curl https://download.hyper.space/api/install | bash 2>&1 | tee -a "$INSTALL_LOG"
    if ! check_status "Failed to install Hyperspace"; then
        return 1
    fi

    # Download aios.sh
    echo "Downloading aios.sh..." | tee -a "$INSTALL_LOG"
    wget https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/aios.sh 2>&1 | tee -a "$INSTALL_LOG"
    if ! check_status "Failed to download aios.sh"; then
        return 1
    fi
    chmod +x aios.sh

    echo -e "${GREEN}Installation completed successfully!${NC}"
    return 0
}

# Function to start Hyperspace
start_hyperspace() {
    echo "Starting Hyperspace in background..."
    if pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Hyperspace is already running${NC}"
        return 1
    fi
    
    nohup aios-cli start > "$RUNTIME_LOG" 2>&1 &
    HYPERSPACE_PID=$!
    echo -e "${GREEN}Hyperspace started with PID: $HYPERSPACE_PID${NC}"
    return 0
}

# Function to stop Hyperspace
stop_hyperspace() {
    echo "Stopping Hyperspace..."
    if pkill -f "aios-cli"; then
        echo -e "${GREEN}Hyperspace stopped successfully${NC}"
        return 0
    else
        echo -e "${YELLOW}No running Hyperspace instance found${NC}"
        return 1
    fi
}

# Function to restart Hyperspace
restart_hyperspace() {
    stop_hyperspace
    sleep 2
    start_hyperspace
}

# Function to check Hyperspace status
check_status_hyperspace() {
    if pgrep -f "aios-cli" > /dev/null; then
        PID=$(pgrep -f "aios-cli")
        echo -e "${GREEN}Hyperspace is running (PID: $PID)${NC}"
    else
        echo -e "${YELLOW}Hyperspace is not running${NC}"
    fi
}

# Function to view logs
view_logs() {
    echo "1) View installation logs"
    echo "2) View runtime logs"
    echo "3) Back to main menu"
    read -p "Select an option: " log_choice

    case $log_choice in
        1) tail -f "$INSTALL_LOG" ;;
        2) tail -f "$RUNTIME_LOG" ;;
        3) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

# Main menu
while true; do
    echo
    echo "=== Hyperspace Manager ==="
    echo "1) Install Hyperspace"
    echo "2) Start Hyperspace"
    echo "3) Stop Hyperspace"
    echo "4) Restart Hyperspace"
    echo "5) Check Hyperspace Status"
    echo "6) View Logs"
    echo "7) Exit"
    echo "======================="
    
    read -p "Select an option: " choice
    echo

    case $choice in
        1) install_hyperspace ;;
        2) start_hyperspace ;;
        3) stop_hyperspace ;;
        4) restart_hyperspace ;;
        5) check_status_hyperspace ;;
        6) view_logs ;;
        7) 
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
done
