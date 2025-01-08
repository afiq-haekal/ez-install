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

# Function to setup Hyperspace path
setup_hyperspace_path() {
    echo "Setting up Hyperspace path..."
    
    # Add .aios to PATH if not already there
    if ! grep -q "/.aios" ~/.bashrc; then
        echo 'export PATH=$HOME/.aios:$PATH' >> ~/.bashrc
    fi
    
    # Export path for current session
    export PATH=$HOME/.aios:$PATH
    
    # Verify aios-cli is accessible
    if command -v aios-cli &>/dev/null; then
        echo -e "${GREEN}aios-cli is now accessible at: $(which aios-cli)${NC}"
        return 0
    else
        echo -e "${RED}Error: aios-cli still not accessible${NC}"
        return 1
    fi
}
setup_cuda_symlinks() {
    echo "Setting up CUDA symlinks..."
    
    # Create symlink for cuda
    if [ ! -e "/usr/local/cuda" ]; then
        echo "Creating symlink for /usr/local/cuda"
        sudo ln -sf /usr/local/cuda-12.3 /usr/local/cuda
    fi
    
    # Create symlinks for specific libraries if they don't exist
    local lib_files=("libcuda.so" "libcuda.so.1" "libnvidia-ml.so" "libnvidia-ml.so.1")
    for lib in "${lib_files[@]}"; do
        if [ ! -e "/usr/lib/x86_64-linux-gnu/$lib" ] && [ -e "/usr/lib/x86_64-linux-gnu/$lib.535.183.01" ]; then
            echo "Creating symlink for $lib"
            sudo ln -sf "/usr/lib/x86_64-linux-gnu/$lib.535.183.01" "/usr/lib/x86_64-linux-gnu/$lib"
        fi
    done
    
    # Update library cache
    sudo ldconfig

    # Verify symlinks
    echo "Verifying symlinks..."
    ls -la /usr/local/cuda
    ls -la /usr/lib/x86_64-linux-gnu/libcuda.so*
    ls -la /usr/lib/x86_64-linux-gnu/libnvidia-ml.so*
}

# Function to reload CUDA path
reload_cuda_path() {
    echo "Reloading CUDA environment..."
    
    # Setup symlinks first
    setup_cuda_symlinks
    
    # Remove old CUDA paths
    PATH=$(echo $PATH | tr ":" "\n" | grep -v "cuda" | tr "\n" ":" | sed 's/:$//')
    LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr ":" "\n" | grep -v "cuda" | tr "\n" ":" | sed 's/:$//')
    
    # Add CUDA paths
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    
    # Update bashrc if needed
    if ! grep -q "cuda/bin" ~/.bashrc; then
        echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    fi
    
    source ~/.bashrc
}

# Function to verify CUDA installation
verify_cuda() {
    echo "Verifying CUDA installation..."
    
    # Check nvidia-smi
    if ! nvidia-smi &>/dev/null; then
        echo -e "${RED}Error: nvidia-smi not working${NC}"
        return 1
    fi
    
    # Try to locate nvcc
    local nvcc_path=""
    if command -v nvcc &>/dev/null; then
        nvcc_path=$(command -v nvcc)
    elif [ -f "/usr/local/cuda/bin/nvcc" ]; then
        nvcc_path="/usr/local/cuda/bin/nvcc"
    fi
    
    if [ -z "$nvcc_path" ]; then
        echo -e "${YELLOW}nvcc not found in PATH. Attempting to reload CUDA environment...${NC}"
        reload_cuda_path
        
        # Check again after reload
        if command -v nvcc &>/dev/null; then
            nvcc_path=$(command -v nvcc)
        elif [ -f "/usr/local/cuda/bin/nvcc" ]; then
            nvcc_path="/usr/local/cuda/bin/nvcc"
        else
            echo -e "${RED}Error: nvcc not found even after reloading PATH${NC}"
            echo -e "${YELLOW}Checking CUDA installation:${NC}"
            echo "1. CUDA directory content:"
            ls -l /usr/local/cuda/bin || echo "Directory not found"
            echo "2. Current PATH:"
            echo $PATH
            return 1
        fi
    fi
    
    # Verify nvcc works
    if ! $nvcc_path --version &>/dev/null; then
        echo -e "${RED}Error: nvcc found at $nvcc_path but failed to execute${NC}"
        return 1
    fi
    
    echo -e "${GREEN}CUDA verification successful:${NC}"
    nvidia-smi
    $nvcc_path --version
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

    # Check if CUDA is already installed and setup properly
    if ! verify_cuda; then
        echo -e "${YELLOW}CUDA not properly configured. Attempting to reconfigure...${NC}" | tee -a "$INSTALL_LOG"
        reload_cuda_path
        if ! verify_cuda; then
            echo -e "${RED}Failed to configure CUDA${NC}" | tee -a "$INSTALL_LOG"
            return 1
        fi
    fi

    # Install Hyperspace
    echo "Installing Hyperspace..." | tee -a "$INSTALL_LOG"
    curl https://download.hyper.space/api/install | bash 2>&1 | tee -a "$INSTALL_LOG"
    check_status "Failed to install Hyperspace" || return 1

    # Setup Hyperspace path
    echo "Setting up Hyperspace environment..." | tee -a "$INSTALL_LOG"
    setup_hyperspace_path

    # Verify aios-cli installation
    if ! command -v aios-cli &>/dev/null; then
        echo -e "${RED}Error: aios-cli not found after installation${NC}" | tee -a "$INSTALL_LOG"
        echo "Checking common installation locations:" | tee -a "$INSTALL_LOG"
        ls -l ~/.local/bin/aios-cli 2>&1 | tee -a "$INSTALL_LOG" || echo "Not found in ~/.local/bin"
        ls -l /usr/local/bin/aios-cli 2>&1 | tee -a "$INSTALL_LOG" || echo "Not found in /usr/local/bin"
        ls -l ~/.aios/aios-cli 2>&1 | tee -a "$INSTALL_LOG" || echo "Not found in ~/.aios"
        
        # Try to find aios-cli
        echo "Searching for aios-cli..." | tee -a "$INSTALL_LOG"
        find ~/ -name aios-cli 2>/dev/null | tee -a "$INSTALL_LOG"
        
        return 1
    fi

    echo -e "${GREEN}aios-cli found at: $(which aios-cli)${NC}" | tee -a "$INSTALL_LOG"

    # Check if aios.sh exists
    if [ -f "aios.sh" ]; then
        echo -e "${GREEN}aios.sh already exists, skipping download${NC}" | tee -a "$INSTALL_LOG"
    else
        echo "Downloading aios.sh..." | tee -a "$INSTALL_LOG"
        wget https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/aios.sh 2>&1 | tee -a "$INSTALL_LOG"
        check_status "Failed to download aios.sh" || return 1
        chmod +x aios.sh
    fi

    echo -e "${GREEN}Installation completed successfully!${NC}"
    return 0
}

# Function to start Hyperspace
start_hyperspace() {
    echo "Starting Hyperspace in background..."
    
    # Source bashrc in parent shell first
    echo "Loading environment variables..."
    source ~/.bashrc
    
    # Verify aios-cli is available
    if ! command -v aios-cli &>/dev/null; then
        echo -e "${RED}Error: aios-cli not found in PATH${NC}"
        echo "Current PATH: $PATH"
        echo -e "${YELLOW}Try opening a new terminal or running: source ~/.bashrc${NC}"
        return 1
    fi

    if pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Hyperspace is already running${NC}"
        return 1
    fi
    
    # Verify CUDA before starting
    if ! verify_cuda; then
        echo -e "${YELLOW}CUDA not properly configured. Attempting to reconfigure...${NC}"
        reload_cuda_path
        source ~/.bashrc
        if ! verify_cuda; then
            echo -e "${RED}Failed to configure CUDA. Cannot start Hyperspace.${NC}"
            return 1
        fi
    fi
    
    # Start Hyperspace with full path exports
    (
        export PATH=/usr/local/cuda/bin:$PATH
        export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
        nohup aios-cli start > "$RUNTIME_LOG" 2>&1 &
    )
    
    # Wait a moment to check if process started
    sleep 2
    
    if pgrep -f "aios-cli" > /dev/null; then
        HYPERSPACE_PID=$(pgrep -f "aios-cli")
        echo -e "${GREEN}Hyperspace started with PID: $HYPERSPACE_PID${NC}"
        return 0
    else
        echo -e "${RED}Failed to start Hyperspace. Check runtime logs for details.${NC}"
        echo "Last few lines of runtime log:"
        tail -n 5 "$RUNTIME_LOG"
        return 1
    fi
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
    echo "7) Reload CUDA Path"
    echo "8) Exit"
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
            reload_cuda_path
            if verify_cuda; then
                echo -e "${GREEN}CUDA path reloaded successfully${NC}"
            else
                echo -e "${RED}Failed to reload CUDA path${NC}"
            fi
            ;;
        8) 
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
