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

# Function to get GaiaNet address from Docker logs
get_gaianet_address() {
    echo -e "${BLUE}Getting GaiaNet address from Docker logs...${NC}"
    # Wait for the container to output the address
    sleep 5
    ADDRESS=$(docker logs gaianet 2>&1 | grep "GaiaNet node is started at:" | grep -o "0x[a-fA-F0-9]\{40\}")
    
    if [ -n "$ADDRESS" ]; then
        echo -e "${GREEN}Found GaiaNet address: ${ADDRESS}${NC}"
        return 0
    else
        echo -e "${RED}Could not find GaiaNet address in logs${NC}"
        return 1
    fi
}

# Function to set up Gaia bot
setup_bot() {
    echo -e "${BLUE}Setting up Gaia bot...${NC}"
    
    # Clone the repository
    git clone https://github.com/afiq-haekal/Gaianet-API-Bot.git
    cd Gaianet-API-Bot
    
    # Copy sample.env to .env
    if [ -f "sample.env" ]; then
        cp sample.env .env
        echo -e "${GREEN}Created .env file from sample.env${NC}"
        
        # Get GaiaNet address and update .env
        if get_gaianet_address; then
            # Update the API_URL in .env
            sed -i "s/0x[a-fA-F0-9]\{40\}/${ADDRESS}/" .env
            echo -e "${GREEN}Updated API_URL in .env with address: ${ADDRESS}${NC}"
        else
            echo -e "${RED}Failed to update API_URL in .env. Please update manually.${NC}"
        fi
    else
        echo -e "${RED}sample.env not found!${NC}"
        exit 1
    fi
    
    # Install requirements
    pip install -r requirements.txt
    
    # Run the bot with nohup
    echo -e "${BLUE}Starting the bot with nohup...${NC}"
    nohup python3 main.py > bot.log 2>&1 &
    
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
