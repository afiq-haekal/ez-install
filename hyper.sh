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
    local message="$1"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $message${NC}"
        return 1
    fi
    return 0
}

# Function to reload environment variables
reload_environment() {
    echo "Reloading environment variables..." | tee -a "$INSTALL_LOG"
    if [ -f ~/.bashrc ]; then
        # Export CUDA paths directly
        export PATH=/usr/local/cuda-12.3/bin:$PATH
        export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH
        
        # Then source bashrc
        source ~/.bashrc
        
        # Verify CUDA path
        if [ -d "/usr/local/cuda-12.3/bin" ]; then
            echo -e "${GREEN}CUDA path verified${NC}" | tee -a "$INSTALL_LOG"
        else
            echo -e "${RED}CUDA installation path not found${NC}" | tee -a "$INSTALL_LOG"
            return 1
        fi
        
        echo -e "${GREEN}Environment variables reloaded successfully${NC}" | tee -a "$INSTALL_LOG"
    else
        echo -e "${RED}Error: ~/.bashrc not found${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}Error: Cannot determine OS version${NC}"
        return 1
    fi

    source /etc/os-release
    UBUNTU_VERSION=$VERSION_ID

    echo "Detected Ubuntu version: $UBUNTU_VERSION"

    if [ "$UBUNTU_VERSION" == "24.04" ]; then
        echo -e "${GREEN}Ubuntu version 24.04 detected. Compatible with CUDA installation.${NC}"
        CUDA_DEB="cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb"  # Using 22.04 package for now
        echo -e "${YELLOW}Note: Using CUDA package for Ubuntu 22.04 as 24.04 package might not be available yet${NC}"
        return 0
    elif [ "$UBUNTU_VERSION" == "22.04" ]; then
        echo -e "${GREEN}Ubuntu version 22.04 detected. Compatible with CUDA installation.${NC}"
        CUDA_DEB="cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb"
        return 0
    elif [ "$UBUNTU_VERSION" == "20.04" ]; then
        echo -e "${GREEN}Ubuntu version 20.04 detected. Using compatible CUDA version.${NC}"
        CUDA_DEB="cuda-repo-ubuntu2004-12-3-local_12.3.1-545.23.08-1_amd64.deb"
        return 0
    else
        echo -e "${RED}Unsupported Ubuntu version: $UBUNTU_VERSION${NC}"
        return 1
    fi
}

# Function to install CUDA
install_cuda() {
    echo "Starting CUDA installation..." | tee -a "$INSTALL_LOG"

    # Check Ubuntu version first
    if ! check_ubuntu_version; then
        echo -e "${RED}Failed to verify Ubuntu version${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi

    # Download CUDA installer
    echo "Downloading CUDA installer..." | tee -a "$INSTALL_LOG"
    wget "https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/${CUDA_DEB}" 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to download CUDA installer" || return 1

    # Install CUDA
    echo "Installing CUDA..." | tee -a "$INSTALL_LOG"
    sudo dpkg -i "${CUDA_DEB}" 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to install CUDA repository" || return 1

    sudo cp /var/cuda-repo-*/cuda-*-keyring.gpg /usr/share/keyrings/ 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to copy CUDA keyring" || return 1

    sudo apt-get update 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to update package list" || return 1

    sudo apt-get -y install cuda-toolkit-12-3 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to install CUDA toolkit" || return 1

    # Set up CUDA environment variables if not already set
    if ! grep -q "cuda-12.3" ~/.bashrc; then
        echo 'export PATH=/usr/local/cuda-12.3/bin:$PATH' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    fi

    # Export paths immediately for current session
    export PATH=/usr/local/cuda-12.3/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH

    # Reload environment variables
    reload_environment
    
    echo -e "${GREEN}CUDA installation completed${NC}"
    return 0
}

# Function to verify CUDA installation
verify_cuda() {
    echo "Verifying CUDA installation..."
    
    # Ensure environment variables are loaded
    reload_environment
    
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

# Function to check and download aios.sh
check_aios_script() {
    if [ -f "aios.sh" ]; then
        echo -e "${GREEN}aios.sh already exists${NC}" | tee -a "$INSTALL_LOG"
        # Verify if the file is executable
        if [ ! -x "aios.sh" ]; then
            echo "Making aios.sh executable..." | tee -a "$INSTALL_LOG"
            chmod +x aios.sh
        fi
        return 0
    else
        echo "Downloading aios.sh..." | tee -a "$INSTALL_LOG"
        wget https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/aios.sh 2>&1 | tee -a "$INSTALL_LOG"
        if [ $? -eq 0 ]; then
            chmod +x aios.sh
            echo -e "${GREEN}aios.sh downloaded and made executable${NC}" | tee -a "$INSTALL_LOG"
            return 0
        else
            echo -e "${RED}Failed to download aios.sh${NC}" | tee -a "$INSTALL_LOG"
            return 1
        fi
    fi
}

# Function to install Hyperspace
install_hyperspace() {
    echo "Starting installation process..." | tee -a "$INSTALL_LOG"

    # Check if NVIDIA GPU is present
    if ! lspci | grep -i nvidia > /dev/null; then
        echo -e "${RED}Error: No NVIDIA GPU detected${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi

    # Ensure environment variables are loaded
    reload_environment

    # Check if CUDA is already installed
    if verify_cuda; then
        echo -e "${GREEN}CUDA is already installed and working properly.${NC}" | tee -a "$INSTALL_LOG"
    else
        echo -e "${YELLOW}CUDA not found or not working properly. Installing CUDA...${NC}" | tee -a "$INSTALL_LOG"
        if ! install_cuda; then
            echo -e "${RED}CUDA installation failed${NC}" | tee -a "$INSTALL_LOG"
            return 1
        fi
        
        # Verify CUDA installation again
        if ! verify_cuda; then
            echo -e "${RED}CUDA verification failed after installation${NC}" | tee -a "$INSTALL_LOG"
            return 1
        fi
    fi

    # Install Hyperspace
    echo "Installing Hyperspace..." | tee -a "$INSTALL_LOG"
    curl https://download.hyper.space/api/install | bash 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to install Hyperspace" || return 1

    # Check and download aios.sh if needed
    if ! check_aios_script; then
        echo -e "${RED}Failed to setup aios.sh${NC}" | tee -a "$INSTALL_LOG"
        return 1
    fi

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
