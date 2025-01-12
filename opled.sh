#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${2}$1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install NVM
install_nvm() {
    if ! command_exists nvm; then
        print_status "Installing NVM..." "$YELLOW"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # Load NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        if command_exists nvm; then
            print_status "NVM installed successfully!" "$GREEN"
        else
            print_status "Failed to install NVM. Please install it manually." "$RED"
            exit 1
        fi
    else
        print_status "NVM is already installed" "$GREEN"
    fi
}

# Check and install Node.js
install_node() {
    if ! command_exists node; then
        print_status "Installing latest Node.js version..." "$YELLOW"
        nvm install node
        nvm use node
        if command_exists node; then
            print_status "Node.js installed successfully!" "$GREEN"
        else
            print_status "Failed to install Node.js. Please install it manually." "$RED"
            exit 1
        fi
    else
        print_status "Node.js is already installed" "$GREEN"
    fi
}

# Check and install PM2
install_pm2() {
    if ! command_exists pm2; then
        print_status "Installing PM2..." "$YELLOW"
        npm install -g pm2
        if command_exists pm2; then
            print_status "PM2 installed successfully!" "$GREEN"
        else
            print_status "Failed to install PM2. Please install it manually." "$RED"
            exit 1
        fi
    else
        print_status "PM2 is already installed" "$GREEN"
    fi
}

# Main installation process
main() {
    print_status "Starting installation process..." "$YELLOW"
    
    # Install prerequisites
    install_nvm
    install_node
    install_pm2
    
    # Clone repository
    print_status "Cloning repository..." "$YELLOW"
    git clone https://github.com/Zlkcyber/opledBot.git
    cd opledBot || exit
    
    # Install dependencies
    print_status "Installing dependencies..." "$YELLOW"
    npm install
    
    # Create example files if they don't exist
    if [ ! -f wallets.txt ]; then
        print_status "Creating wallets.txt..." "$YELLOW"
        touch wallets.txt
        echo "# Add your wallet addresses here, one per line" > wallets.txt
    fi
    
    if [ ! -f proxy.txt ]; then
        print_status "Creating proxy.txt..." "$YELLOW"
        touch proxy.txt
        echo "# Add your proxies here, one per line" > proxy.txt
        echo "# Format: protocol://user:password@ip:port or protocol://ip:port" >> proxy.txt
    fi
    
    print_status "Installation completed!" "$GREEN"
    print_status "\nNext steps:" "$YELLOW"
    print_status "1. Add your wallet addresses to wallets.txt" "$NC"
    print_status "2. (Optional) Add your proxies to proxy.txt" "$NC"
    print_status "3. Start the bot with: pm2 start 'npm run start' --name opledBot" "$NC"
}

# Run main function
main
