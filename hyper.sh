#!/bin/bash

# Set log file location
LOG_FILE="$HOME/hyperspace_install.log"
echo "Installation log will be available at: $LOG_FILE"

# Function to check if command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to verify CUDA installation
verify_cuda() {
    echo "Verifying CUDA installation..." | tee -a "$LOG_FILE"
    
    # Check nvidia-smi
    if ! nvidia-smi &>/dev/null; then
        echo "Error: nvidia-smi not working" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Check nvcc
    if ! nvcc --version &>/dev/null; then
        echo "Error: nvcc not found in PATH" | tee -a "$LOG_FILE"
        return 1
    fi
    
    echo "CUDA verification successful:" | tee -a "$LOG_FILE"
    nvidia-smi | tee -a "$LOG_FILE"
    nvcc --version | tee -a "$LOG_FILE"
    return 0
}

echo "Starting installation process..." | tee -a "$LOG_FILE"

# Check if NVIDIA GPU is present
if ! lspci | grep -i nvidia > /dev/null; then
    echo "Error: No NVIDIA GPU detected" | tee -a "$LOG_FILE"
    exit 1
fi

# Check if CUDA is already installed
if verify_cuda; then
    echo "CUDA is already installed and working properly. Skipping CUDA installation." | tee -a "$LOG_FILE"
else
    echo "CUDA installation needed. Starting CUDA installation..." | tee -a "$LOG_FILE"
    
    # Download CUDA installer
    wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to download CUDA installer"

    # Install CUDA
    sudo dpkg -i cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to install CUDA repository"

    sudo cp /var/cuda-repo-ubuntu2204-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/ 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to copy CUDA keyring"

    sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to update package list"

    sudo apt-get -y install cuda-toolkit-12-3 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to install CUDA toolkit"

    # Set up CUDA environment variables if not already set
    if ! grep -q "cuda-12.3" ~/.bashrc; then
        echo 'export PATH=/usr/local/cuda-12.3/bin:$PATH' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    fi

    # Source bashrc
    echo "Sourcing ~/.bashrc..." | tee -a "$LOG_FILE"
    source ~/.bashrc

    # Verify CUDA installation
    if ! verify_cuda; then
        echo "Error: CUDA installation failed verification" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

# Install Hyperspace
echo "Installing Hyperspace..." | tee -a "$LOG_FILE"
curl https://download.hyper.space/api/install | bash 2>&1 | tee -a "$LOG_FILE"
check_status "Failed to install Hyperspace"

# Download aios.sh (without executing)
echo "Downloading aios.sh..." | tee -a "$LOG_FILE"
wget https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/aios.sh 2>&1 | tee -a "$LOG_FILE"
check_status "Failed to download aios.sh"
chmod +x aios.sh

# Start Hyperspace using nohup
echo "Starting Hyperspace in background..." | tee -a "$LOG_FILE"
nohup aios-cli start > "$HOME/hyperspace_runtime.log" 2>&1 &
HYPERSPACE_PID=$!
echo "Hyperspace started with PID: $HYPERSPACE_PID" | tee -a "$LOG_FILE"

echo "Installation completed successfully!" | tee -a "$LOG_FILE"
echo "You can monitor Hyperspace logs at: $HOME/hyperspace_runtime.log" | tee -a "$LOG_FILE"
echo "Installation logs are available at: $LOG_FILE" | tee -a "$LOG_FILE"
echo "aios.sh has been downloaded and is ready for use" | tee -a "$LOG_FILE"
