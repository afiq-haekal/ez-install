#!/bin/bash

# Function to check if script exists
check_file() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to download scripts
download_scripts() {
    echo "Downloading installation scripts..."
    
    # Download Ollama installer
    if ! curl -sSL https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/infera/install-ollama.sh -o install-ollama.sh; then
        echo "Failed to download Ollama installer"
        exit 1
    fi
    
    # Download Infera installer
    if ! curl -sSL https://raw.githubusercontent.com/afiq-haekal/ez-install/refs/heads/main/infera/install-infera.sh -o install-infera.sh; then
        echo "Failed to download Infera installer"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x install-ollama.sh install-infera.sh
    echo "Scripts downloaded successfully"
}

# Main installation process
main() {
    echo "Starting installation process..."
    
    # Download scripts if they don't exist
    if ! check_file "install-ollama.sh" || ! check_file "install-infera.sh"; then
        download_scripts
    fi
    
    # Run Ollama installer
    echo "Installing Ollama..."
    if ! ./install-ollama.sh; then
        echo "Ollama installation failed"
        exit 1
    fi
    echo "Ollama installation completed"
    
    # Run Infera installer
    echo "Installing Infera..."
    if ! ./install-infera.sh; then
        echo "Infera installation failed"
        exit 1
    fi
    echo "Infera installation completed"
    
    echo "All installations completed successfully!"
    echo "Use 'docker compose logs -f' to check Ollama status"
    echo "Use 'pm2 status' to check Infera status"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Run main installation
main
