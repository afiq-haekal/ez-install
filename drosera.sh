#!/bin/bash

# Exit script on error
set -e

# Color codes for better readability
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================${NC}"
echo -e "${GREEN}Drosera Network Auto-Installation Script${NC}"
echo -e "${BLUE}========================================================${NC}"

# Function to display step information
step_info() {
    echo -e "\n${YELLOW}[Step $1]${NC} $2"
}

# Function to display success message
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to prompt for user input with default value
prompt_with_default() {
    local prompt=$1
    local default=$2
    local input
    
    read -p "$(echo -e "${YELLOW}$prompt [default: $default]:${NC} ")" input
    echo "${input:-$default}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get valid numbered choice
get_valid_choice() {
    local prompt=$1
    local min=$2
    local max=$3
    local choice=""
    
    while true; do
        read -p "$(echo -e "${YELLOW}$prompt (Enter $min-$max):${NC} ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ]; then
            echo "$choice"
            return
        else
            echo -e "${RED}Invalid choice. Please enter a number between $min and $max.${NC}"
        fi
    done
}

# Step 1: Update system packages
step_info "1" "Updating and upgrading system packages"
sudo apt-get update && sudo apt-get upgrade -y
success_msg "System packages updated"

# Step 2: Install required dependencies
step_info "2" "Installing required dependencies"
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
success_msg "Dependencies installed"

# Check for Docker and install if needed
if ! command_exists docker; then
    step_info "2.1" "Installing Docker"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable docker
    sudo systemctl start docker
    success_msg "Docker installed"
else
    success_msg "Docker is already installed"
fi

# Step 3: Configure Environment - Drosera CLI
step_info "3" "Setting up Drosera CLI"
if ! command_exists droseraup; then
    curl -L https://app.drosera.io/install | bash
    echo "export PATH=\$HOME/.drosera/bin:\$PATH" >> ~/.bashrc
    export PATH=$HOME/.drosera/bin:$PATH
    droseraup
    success_msg "Drosera CLI installed"
else
    success_msg "Drosera CLI is already installed"
fi

# Step 4: Configure Environment - Foundry CLI
step_info "4" "Setting up Foundry CLI"
if ! command_exists foundryup; then
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    echo "export PATH=\$HOME/.foundry/bin:\$PATH" >> ~/.bashrc
    foundryup
    success_msg "Foundry CLI installed"
else
    success_msg "Foundry CLI is already installed"
fi

# Step 5: Install Bun
step_info "5" "Setting up Bun"
if ! command_exists bun; then
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo "export BUN_INSTALL=\"\$HOME/.bun\"" >> ~/.bashrc
    echo "export PATH=\"\$BUN_INSTALL/bin:\$PATH\"" >> ~/.bashrc
    success_msg "Bun installed"
else
    success_msg "Bun is already installed"
fi

# Ask user what they want to install
echo -e "\n${BLUE}========================================================${NC}"
echo -e "${GREEN}What would you like to install?${NC}"
echo -e "${YELLOW}1. Trap Only${NC}"
echo -e "${YELLOW}2. Operator Only${NC}"
echo -e "${YELLOW}3. Both Trap and Operator${NC}"
MODE=$(get_valid_choice "Enter your choice" 1 3)
echo -e "${BLUE}========================================================${NC}"

# Install Trap if selected
if [[ "$MODE" == "1" || "$MODE" == "3" ]]; then
    echo -e "\n${GREEN}Starting Trap Installation${NC}"
    
    # Step 6: Setup Git Configuration
    step_info "6" "Setting up Git configuration"
    echo -e "${YELLOW}Please enter your GitHub information${NC}"
    GIT_EMAIL=$(prompt_with_default "Enter your GitHub email" "example@github.com")
    GIT_USERNAME=$(prompt_with_default "Enter your GitHub username" "github-user")

    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_USERNAME"
    success_msg "Git configured with email: $GIT_EMAIL and username: $GIT_USERNAME"

    # Step 7: Create and enter project directory
    step_info "7" "Creating project directory"
    mkdir -p my-drosera-trap
    cd my-drosera-trap
    success_msg "Project directory created and entered"

    # Step 8: Initialize Trap with Foundry
    step_info "8" "Initializing Trap with Foundry template"
    forge init -t drosera-network/trap-foundry-template
    success_msg "Trap initialized"

    # Step 9: Install dependencies and build
    step_info "9" "Installing dependencies and building"
    bun install
    forge build
    success_msg "Dependencies installed and project built"

    # Step 10: Deploy Trap
    step_info "10" "Deploying Trap"
    echo -e "${YELLOW}Please enter your EVM wallet private key (must be funded with Holesky ETH)${NC}"
    read -p "Private key: " PRIVATE_KEY

    echo -e "${YELLOW}Running deployment command. When prompted, type 'ofc' and press Enter.${NC}"
    DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
    success_msg "Trap deployed"

    # Step 11: Instructions for checking trap and bloom boost
    step_info "11" "Final Steps for Trap"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${GREEN}Trap Installation Complete!${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "1. Connect your Drosera EVM wallet at: ${BLUE}https://app.drosera.io/${NC}"
    echo -e "2. Click on 'Traps Owned' to see your deployed Traps"
    echo -e "3. Open your Trap on Dashboard and Click on 'Send Bloom Boost'"
    echo -e "4. Deposit some Holesky ETH on it"
    echo -e "\nTo fetch blocks, run: ${GREEN}drosera dryrun${NC}"
fi

# Install Operator if selected
if [[ "$MODE" == "2" || "$MODE" == "3" ]]; then
    # If both were selected and we just installed a trap, we need the private key again
    if [[ "$MODE" == "3" ]]; then
        cd ~
    else
        echo -e "\n${GREEN}Starting Operator Installation${NC}"
        echo -e "${YELLOW}Please enter your EVM wallet private key (must be funded with Holesky ETH)${NC}"
        read -p "Private key: " PRIVATE_KEY
    fi

    # Step 1: Whitelist Operator Address (if trap already deployed)
    if [[ "$MODE" == "2" ]]; then
        step_info "1.1" "Do you need to whitelist your operator in an existing trap?"
        echo -e "${YELLOW}1. Yes - I need to whitelist my operator in an existing trap${NC}"
        echo -e "${YELLOW}2. No - I don't need to whitelist an operator${NC}"
        NEED_WHITELIST=$(get_valid_choice "Enter your choice" 1 2)
        
        if [[ "$NEED_WHITELIST" == "1" ]]; then
            echo -e "${YELLOW}Please enter your Operator EVM address (public address)${NC}"
            read -p "Operator address: " OPERATOR_ADDRESS
            
            echo -e "${YELLOW}Enter the path to your trap directory [default: my-drosera-trap]:${NC}"
            read -p "> " TRAP_DIR
            TRAP_DIR=${TRAP_DIR:-"my-drosera-trap"}
            
            cd "$TRAP_DIR"
            # Edit drosera.toml properly
            echo -e "\n${YELLOW}Editing drosera.toml to add your operator to whitelist${NC}"
            
            # Default trap directory
            TRAP_DIR=${TRAP_DIR:-"my-drosera-trap"}
            
            # Check if the file exists
            if [ -f "drosera.toml" ]; then
                # Check if whitelist already exists
                if grep -q "whitelist = \[" drosera.toml; then
                    # Extract existing whitelist
                    echo -e "${YELLOW}Existing whitelist found, updating it...${NC}"
                    # Use sed to replace the whitelist entry
                    sed -i "s/whitelist = \[.*\]/whitelist = \[\"$OPERATOR_ADDRESS\"\]/g" drosera.toml
                    
                    # Make sure private=true is set
                    if ! grep -q "private = true" drosera.toml; then
                        sed -i "s/private = false/private = true/g" drosera.toml
                    fi
                else
                    # No whitelist found, might need to append
                    echo -e "${YELLOW}No whitelist found, will add it...${NC}"
                    # Add whitelist to the correct trap section
                    sed -i "/\[traps.mytrap\]/a whitelist = [\"$OPERATOR_ADDRESS\"]" drosera.toml
                    sed -i "/\[traps.mytrap\]/a private = true" drosera.toml
                fi
            else
                echo -e "${RED}Error: drosera.toml not found in this directory${NC}"
                exit 1
            fi
            
            echo -e "${YELLOW}Updating trap configuration...${NC}"
            DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
            success_msg "Operator whitelisted in trap"
        fi
    else
        # If we just deployed a trap, whitelist the operator
        step_info "1.1" "Whitelisting operator in newly deployed trap"
        echo -e "${YELLOW}Please enter your Operator EVM address (public address)${NC}"
        read -p "Operator address: " OPERATOR_ADDRESS
        
        cd my-drosera-trap
        echo -e "\n${YELLOW}Editing drosera.toml to add your operator to whitelist${NC}"
        echo -e "\nprivate_trap = true\nwhitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
        
        echo -e "${YELLOW}Updating trap configuration...${NC}"
        DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
        success_msg "Operator whitelisted in trap"
        cd ~
    fi

    # Step 2: Install Operator CLI
    step_info "2.1" "Installing Operator CLI"
    cd ~
    curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    
    # Check version
    ./drosera-operator --version
    
    # Move to path
    sudo cp drosera-operator /usr/bin
    success_msg "Operator CLI installed"

    # Step 3: Pull Docker image
    step_info "3.1" "Pulling Docker image"
    docker pull ghcr.io/drosera-network/drosera-operator:latest
    success_msg "Docker image pulled"

    # Step 4: Register Operator
    step_info "4.1" "Registering operator"
    echo -e "${YELLOW}Running registration command: drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key [HIDDEN]${NC}"
    
    # Try to register the operator and capture the output
    set +e  # Disable exit on error temporarily
    REGISTER_OUTPUT=$(drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIVATE_KEY 2>&1)
    REGISTER_STATUS=$?
    set -e  # Re-enable exit on error
    
    echo -e "${YELLOW}Registration command output:${NC}"
    echo "$REGISTER_OUTPUT"
    
    # Check if the output contains the "already registered" error
    if [ $REGISTER_STATUS -eq 0 ]; then
        success_msg "Operator registered successfully"
    elif echo "$REGISTER_OUTPUT" | grep -q "OperatorAlreadyRegistered"; then
        echo -e "${YELLOW}Operator is already registered. Continuing...${NC}"
    else
        echo -e "${RED}Registration failed with status code: $REGISTER_STATUS${NC}"
        echo -e "${YELLOW}Do you want to continue anyway? (y/n)${NC}"
        while true; do
            read -p "> " CONTINUE_AFTER_ERROR
            if [[ "$CONTINUE_AFTER_ERROR" == "y" || "$CONTINUE_AFTER_ERROR" == "Y" ]]; then
                break
            elif [[ "$CONTINUE_AFTER_ERROR" == "n" || "$CONTINUE_AFTER_ERROR" == "N" ]]; then
                echo -e "${RED}Exiting due to registration error.${NC}"
                exit 1
            else
                echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${NC}"
            fi
        done
    fi

    # Step 5: Port Information (without configuring firewall)
    step_info "5.1" "Required ports information"
    echo -e "${YELLOW}Drosera operator requires the following ports to be open:${NC}"
    echo -e "  - TCP port 31313 for P2P communication"
    echo -e "  - TCP port 31314 for server communication"
    echo -e "${YELLOW}Please ensure these ports are accessible on your server.${NC}"
    success_msg "Port information provided"

    # Step 6: Choose installation method
    step_info "6.1" "Choose operator installation method"
    echo -e "${YELLOW}1. Docker - Run operator in a Docker container${NC}"
    echo -e "${YELLOW}2. SystemD - Run operator as a system service${NC}"
    INSTALL_METHOD=$(get_valid_choice "Enter your choice" 1 2)
    
    # Method 1: Docker
    if [[ "$INSTALL_METHOD" == "1" ]]; then
        step_info "6.2" "Configuring Docker"
        
        # Stop any existing systemd service
        if systemctl is-active --quiet drosera; then
            sudo systemctl stop drosera
            sudo systemctl disable drosera
        fi
        
        git clone https://github.com/0xmoei/Drosera-Network
        cd Drosera-Network
        cp .env.example .env
        
        # Get VPS IP
        VPS_IP=$(curl -s icanhazip.com)
        echo -e "${YELLOW}Detected VPS IP: $VPS_IP${NC}"
        echo -e "${YELLOW}Is this correct? (y/n)${NC}"
        while true; do
            read -p "> " CONFIRM_IP
            if [[ "$CONFIRM_IP" == "y" || "$CONFIRM_IP" == "Y" ]]; then
                break
            elif [[ "$CONFIRM_IP" == "n" || "$CONFIRM_IP" == "N" ]]; then
                echo -e "${YELLOW}Please enter your VPS public IP:${NC}"
                read -p "> " VPS_IP
                break
            else
                echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${NC}"
            fi
        done
        
        # Edit .env file
        echo -e "${YELLOW}Editing .env file with your configuration...${NC}"
        if [ -f ".env" ]; then
            # Check that the placeholder texts exist in the file
            if grep -q "your_evm_private_key" .env && grep -q "your_vps_public_ip" .env; then
                # Replace the placeholders with actual values
                sed -i "s/your_evm_private_key/$PRIVATE_KEY/g" .env
                sed -i "s/your_vps_public_ip/$VPS_IP/g" .env
                echo -e "${GREEN}Successfully updated .env file with your private key and IP address${NC}"
            else
                echo -e "${RED}Expected placeholder text not found in .env file${NC}"
                echo -e "${YELLOW}Manually updating .env file...${NC}"
                
                # Create a backup of the original file
                cp .env .env.backup
                
                # Manually set the values
                echo "# Drosera Operator Configuration" > .env
                echo "PRIVATE_KEY=$PRIVATE_KEY" >> .env
                echo "EXTERNAL_IP=$VPS_IP" >> .env
                echo "# Imported from .env.backup:" >> .env
                grep -v "your_evm_private_key\|your_vps_public_ip" .env.backup >> .env
                
                echo -e "${GREEN}Created new .env file with your configuration${NC}"
            fi
        else
            echo -e "${RED}Error: .env file not found!${NC}"
            exit 1
        fi
        
        # Run operator
        step_info "6.3" "Starting operator with Docker"
        docker compose up -d
        
        # Check logs
        step_info "6.4" "Checking operator logs"
        docker compose logs
        success_msg "Operator started with Docker"
        
        echo -e "${YELLOW}Common Docker commands:${NC}"
        echo -e "Stop node: ${GREEN}cd Drosera-Network && docker compose down -v${NC}"
        echo -e "Restart node: ${GREEN}cd Drosera-Network && docker compose up -d${NC}"
        echo -e "View logs: ${GREEN}cd Drosera-Network && docker compose logs -f${NC}"
    
    # Method 2: SystemD
    else
        step_info "6.2" "Configuring SystemD"
        
        # Get VPS IP
        VPS_IP=$(curl -s icanhazip.com)
        echo -e "${YELLOW}Detected VPS IP: $VPS_IP${NC}"
        echo -e "${YELLOW}Is this correct? (y/n)${NC}"
        while true; do
            read -p "> " CONFIRM_IP
            if [[ "$CONFIRM_IP" == "y" || "$CONFIRM_IP" == "Y" ]]; then
                break
            elif [[ "$CONFIRM_IP" == "n" || "$CONFIRM_IP" == "N" ]]; then
                echo -e "${YELLOW}Please enter your VPS public IP:${NC}"
                read -p "> " VPS_IP
                break
            else
                echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${NC}"
            fi
        done
        
        # Create systemd service file
        sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \\
    --eth-backup-rpc-url https://1rpc.io/holesky \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $PRIVATE_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPS_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
        
        # Start service
        step_info "6.3" "Starting operator with SystemD"
        sudo systemctl daemon-reload
        sudo systemctl enable drosera
        sudo systemctl start drosera
        
        # Check logs
        step_info "6.4" "Checking operator logs"
        journalctl -u drosera.service -n 50
        success_msg "Operator started with SystemD"
        
        echo -e "${YELLOW}Common SystemD commands:${NC}"
        echo -e "Stop node: ${GREEN}sudo systemctl stop drosera${NC}"
        echo -e "Restart node: ${GREEN}sudo systemctl restart drosera${NC}"
        echo -e "View logs: ${GREEN}journalctl -u drosera.service -f${NC}"
    fi
    
    # Step 7: Final instructions
    step_info "7.1" "Final Steps"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${GREEN}Operator Installation Complete!${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "1. Connect your Drosera EVM wallet at: ${BLUE}https://app.drosera.io/${NC}"
    echo -e "2. Navigate to your trap and click 'Opt-in' to connect your operator"
    echo -e "3. Your node will start producing green blocks in the dashboard when successful"
    echo -e "\nNote: It's normal to see WARN messages about 'Failed to gossip message: InsufficientPeers'"
fi

echo -e "\n${BLUE}========================================================${NC}"
echo -e "${GREEN}Drosera Network Setup Complete!${NC}"
echo -e "${BLUE}========================================================${NC}"