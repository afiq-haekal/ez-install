#!/bin/bash

# Function to detect OS and CPU type
detect_system() {
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        # Check if M series
        if [[ $(uname -m) == "arm64" ]]; then
            CPU_TYPE="apple-m"
        else
            CPU_TYPE="intel"
        fi
    else
        OS="linux"
        # Detect CPU on Linux
        if grep -q "GenuineIntel" /proc/cpuinfo; then
            CPU_TYPE="intel"
        elif grep -q "AuthenticAMD" /proc/cpuinfo; then
            CPU_TYPE="amd"
        else
            echo "Unsupported CPU architecture"
            exit 1
        fi
    fi
}

# Function to install Node.js and npm if not present
install_node() {
    if ! command -v node &> /dev/null; then
        echo "Installing Node.js and npm..."
        if [[ "$OS" == "macos" ]]; then
            # Install using Homebrew for macOS
            if ! command -v brew &> /dev/null; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install node
        else
            # Install using apt for Linux
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    fi
}

# Function to install PM2 if not present
install_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo "Installing PM2..."
        sudo npm install -g pm2
    fi
}

# Function to install Infera based on detected system
install_infera() {
    echo "Installing Infera for $CPU_TYPE CPU..."
    
    if [[ "$OS" == "macos" ]]; then
        curl -sSL http://downloads.infera.org/infera-apple-m.sh | bash
        # Add alias to zshrc
        echo "alias init-infera='~/infera'" >> ~/.zshrc
        source ~/.zshrc
    else
        # Linux installation
        if [[ "$CPU_TYPE" == "intel" ]]; then
            curl -sSL http://downloads.infera.org/infera-linux-intel.sh | bash
            echo "alias init-infera='~/infera'" >> ~/.bashrc
        elif [[ "$CPU_TYPE" == "amd" ]]; then
            curl -sSL http://downloads.infera.org/infera-linux-amd.sh | bash
            echo "alias init-infera='~/infera'" >> ~/.bashrc
        fi
        source ~/.bashrc
    fi
}

# Function to setup and start Infera with PM2
setup_pm2() {
    echo "Setting up PM2 for Infera..."
    pm2 start ~/infera --name "infera"
    pm2 save
    pm2 startup
}

# Main installation process
main() {
    echo "Starting Infera installation..."
    
    # Detect system
    detect_system
    echo "Detected OS: $OS"
    echo "Detected CPU: $CPU_TYPE"
    
    # Install prerequisites
    install_node
    install_pm2
    
    # Install Infera
    install_infera
    
    # Setup PM2
    setup_pm2
    
    echo "Installation completed!"
    echo "Infera is now running with PM2"
    echo "You can check status with: pm2 status"
    echo "View logs with: pm2 logs infera"
}

# Run main installation
main
