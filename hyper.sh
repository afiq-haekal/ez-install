#!/bin/bash

# Function to check if command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

echo "Starting installation process..."

# Download CUDA installer
wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb
check_status "Failed to download CUDA installer"

# Install CUDA
sudo dpkg -i cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb
check_status "Failed to install CUDA repository"

sudo cp /var/cuda-repo-ubuntu2204-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
check_status "Failed to copy CUDA keyring"

sudo apt-get update
check_status "Failed to update package list"

sudo apt-get -y install cuda-toolkit-12-3
check_status "Failed to install CUDA toolkit"

# Set up CUDA environment variables
echo 'export PATH=/usr/local/cuda-12.3/bin${PATH:+:${PATH}}' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
source ~/.bashrc

# Install Hyperspace
curl https://download.hyper.space/api/install | bash
check_status "Failed to install Hyperspace"
source /root/.bashrc

# Create screen session and start aios-cli
screen -dmS hyperspace bash -c "aios-cli start"
check_status "Failed to create screen session"

# Download and run aios.sh
wget https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/aios.sh
check_status "Failed to download aios.sh"

chmod +x aios.sh
./aios.sh

echo "Installation completed successfully!"
echo "To attach to the hyperspace screen session, use: screen -r hyperspace"
