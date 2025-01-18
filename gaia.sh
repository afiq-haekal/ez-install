#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi
}

# Function to check if Git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git is not installed. Please install Git first.${NC}"
        exit 1
    fi
}

# Function to check and install Python and pip
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Python3 is not installed. Installing Python3...${NC}"
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y python3
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y python3
        else
            echo -e "${RED}Unsupported distribution. Please install Python3 manually.${NC}"
            exit 1
        fi
    fi

    if ! command -v pip &> /dev/null; then
        echo -e "${RED}pip is not installed. Installing pip...${NC}"
        if [ -f /etc/debian_version ]; then
            sudo apt-get install -y python3-pip
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y python3-pip
        else
            echo -e "${RED}Unsupported distribution. Please install pip manually.${NC}"
            exit 1
        fi
    fi
}

# Function to install Gaia using Docker
install_gaia() {
    echo -e "${BLUE}Installing Gaia using Docker...${NC}"
    docker run -d --name gaianet \
        --gpus all \
        -p 8080:8080 \
        -v $(pwd)/qdrant_storage:/root/gaianet/qdrant/storage:z \
        gaianet/phi-3-mini-instruct-4k_paris:cuda12
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Gaia installation completed successfully!${NC}"
    else
        echo -e "${RED}Error during Gaia installation${NC}"
    fi
}

# Function to get Gaia info
get_gaia_info() {
    echo -e "${BLUE}Getting Gaia information...${NC}"
    docker exec -it gaianet /root/gaianet/bin/gaianet info
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully retrieved Gaia information!${NC}"
    else
        echo -e "${RED}Error getting Gaia information${NC}"
    fi
}

# Function to get GaiaNet address from Docker logs with retries
get_gaianet_address() {
    echo -e "${BLUE}Getting GaiaNet address from Docker logs...${NC}"
    local max_attempts=12  # Maximum number of attempts (2 minutes total)
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${BLUE}Attempt $attempt of $max_attempts to get GaiaNet address...${NC}"
        ADDRESS=$(docker logs gaianet 2>&1 | grep "GaiaNet node is started at:" | grep -o "0x[a-fA-F0-9]\{40\}")
        
        if [ -n "$ADDRESS" ]; then
            echo -e "${GREEN}Successfully found GaiaNet address: ${ADDRESS}${NC}"
            return 0
        else
            echo -e "${YELLOW}Address not found yet, waiting 10 seconds...${NC}"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}Failed to get GaiaNet address after $max_attempts attempts${NC}"
    return 1
}

# Function to set up Gaia bot
setup_bot() {
    echo -e "${BLUE}Setting up Gaia bot...${NC}"
    
    # First, try to get GaiaNet address
    if ! get_gaianet_address; then
        echo -e "${RED}Failed to get GaiaNet address. Bot setup aborted.${NC}"
        echo -e "${RED}Please ensure Gaia is running properly and try again.${NC}"
        return 1
    fi
    
    # Only proceed with setup if we have the address
    echo -e "${BLUE}Proceeding with bot setup using address: ${ADDRESS}${NC}"
    
    # Clone the repository
    if ! git clone https://github.com/afiq-haekal/Gaianet-API-Bot.git; then
        echo -e "${RED}Failed to clone repository. Bot setup aborted.${NC}"
        return 1
    fi
    
    cd Gaianet-API-Bot || {
        echo -e "${RED}Failed to enter project directory. Bot setup aborted.${NC}"
        return 1
    }
    
    # Copy and update .env file
    if [ -f "sample.env" ]; then
        cp sample.env .env
        echo -e "${GREEN}Created .env file from sample.env${NC}"
        
        # Update the API_URL in .env
        if sed -i "s/0x[a-fA-F0-9]\{40\}/${ADDRESS}/" .env; then
            echo -e "${GREEN}Successfully updated API_URL in .env with address: ${ADDRESS}${NC}"
        else
            echo -e "${RED}Failed to update API_URL in .env. Bot setup aborted.${NC}"
            return 1
        fi
    else
        echo -e "${RED}sample.env not found! Bot setup aborted.${NC}"
        return 1
    fi
    
    # Install requirements
    echo -e "${BLUE}Installing Python requirements...${NC}"
    if ! pip install -r requirements.txt; then
        echo -e "${RED}Failed to install requirements. Bot setup aborted.${NC}"
        return 1
    fi
    
    # Run the bot with nohup
    echo -e "${BLUE}Starting the bot with nohup...${NC}"
    if ! nohup python3 main.py > bot.log 2>&1 &; then
        echo -e "${RED}Failed to start the bot. Bot setup aborted.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Bot setup completed successfully!${NC}"
    echo -e "${GREEN}Bot logs can be found in bot.log${NC}"
    return 0
}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Bot setup completed successfully! Check bot.log for output.${NC}"
    else
        echo -e "${RED}Error during bot setup${NC}"
    fi
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}=== Gaia Installation and Setup Menu ===${NC}"
    echo "1. Install Gaia"
    echo "2. Get Gaia Info"
    echo "3. Setup Gaia Bot"
    echo "4. Exit"
    echo -e "${BLUE}======================================${NC}\n"
}

# Main loop
while true; do
    show_menu
    read -p "Please select an option (1-4): " choice
    
    case $choice in
        1)
            check_docker
            install_gaia
            ;;
        2)
            check_docker
            get_gaia_info
            ;;
        3)
            check_git
            check_python
            setup_bot
            ;;
        4)
            echo -e "${GREEN}Exiting the installer. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-4${NC}"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read
done
