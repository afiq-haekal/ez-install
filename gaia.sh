#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to configure Discord webhook
configure_discord_webhook() {
    echo -e "${BLUE}Discord Webhook Configuration${NC}"
    echo -e "${YELLOW}The webhook URL should look like: https://discord.com/api/webhooks/ID/TOKEN${NC}"
    
    while true; do
        read -p "Enter your Discord webhook URL (or press Enter to skip): " webhook_url
        
        if [ -z "$webhook_url" ]; then
            echo -e "${YELLOW}Skipping Discord webhook configuration${NC}"
            return 0
        fi
        
        if [[ $webhook_url == https://discordapp.com/api/webhooks/* ]] || [[ $webhook_url == https://discord.com/api/webhooks/* ]]; then
            if grep -q "DISCORD_WEBHOOK_URL=" .env; then
                sed -i "s#DISCORD_WEBHOOK_URL=.*#DISCORD_WEBHOOK_URL=$webhook_url#" .env
            else
                echo "DISCORD_WEBHOOK_URL=$webhook_url" >> .env
            fi
            echo -e "${GREEN}Discord webhook URL configured successfully!${NC}"
            return 0
        else
            echo -e "${RED}Invalid webhook URL format. Please enter a valid Discord webhook URL${NC}"
            read -p "Try again? (y/n): " retry
            if [[ $retry != [Yy]* ]]; then
                echo -e "${YELLOW}Skipping Discord webhook configuration${NC}"
                return 0
            fi
        fi
    done
}

# Function to restore nodeid
restore_nodeid() {
    echo -e "${BLUE}Restore NodeID Configuration${NC}"
    
    while true; do
        read -p "Do you want to restore a nodeid.json file? (y/n): " restore_choice
        
        case $restore_choice in
            [Yy]*)
                read -p "Enter the path to your nodeid.json file: " nodeid_path
                
                if [ -f "$nodeid_path" ]; then
                    if docker cp "$nodeid_path" gaianet:/root/gaianet/nodeid.json; then
                        echo -e "${GREEN}Successfully restored nodeid.json${NC}"
                        echo -e "${YELLOW}Restarting container to apply changes...${NC}"
                        if docker restart gaianet; then
                            echo -e "${GREEN}Container restarted successfully!${NC}"
                            # Clear logs after restart
                            docker logs gaianet --since 0m > /dev/null 2>&1
                            sleep 5  # Wait for container to initialize
                            return 0
                        else
                            echo -e "${RED}Failed to restart container${NC}"
                            return 1
                        fi
                    else
                        echo -e "${RED}Failed to copy nodeid.json to container${NC}"
                        read -p "Try again? (y/n): " retry
                        if [[ $retry != [Yy]* ]]; then
                            return 1
                        fi
                    fi
                else
                    echo -e "${RED}File not found: $nodeid_path${NC}"
                    read -p "Try again? (y/n): " retry
                    if [[ $retry != [Yy]* ]]; then
                        return 1
                    fi
                fi
                ;;
            [Nn]*)
                echo -e "${YELLOW}Skipping nodeid.json restoration${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Please answer yes (y) or no (n)${NC}"
                ;;
        esac
    done
}

# Function to check Docker installation
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker daemon is not running. Please start Docker service.${NC}"
        exit 1
    fi
}

# Function to check Git installation
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git is not installed. Please install Git first.${NC}"
        exit 1
    fi
}

# Function to check Python installation
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

# Function to install Gaia
install_gaia() {
    clear
    echo -e "\n${BLUE}====================================${NC}"
    echo -e "${BLUE}     Installing Gaia via Docker${NC}"
    echo -e "${BLUE}====================================${NC}\n"
    
    # Check for existing container
    if docker ps -a --format '{{.Names}}' | grep -q "^gaianet$"; then
        echo -e "${YELLOW}Existing 'gaianet' container detected${NC}"
        echo -e "1. Stop and remove existing container"
        echo -e "2. Restart existing container"
        echo -e "3. Abort installation"
        
        while true; do
            read -p "Please select an option (1-3): " container_choice
            
            case $container_choice in
                1)
                    echo -e "${YELLOW}Stopping and removing existing container...${NC}"
                    docker stop gaianet
                    docker rm gaianet
                    break
                    ;;
                2)
                    echo -e "${YELLOW}Restarting existing container...${NC}"
                    docker restart gaianet
                    echo -e "${GREEN}Container restarted successfully!${NC}"
                    # Clear logs after restart
                    docker logs gaianet --since 0m > /dev/null 2>&1
                    sleep 5
                    
                    # Ask about nodeid restoration after restart
                    restore_nodeid
                    return 0
                    ;;
                3)
                    echo -e "${YELLOW}Installation aborted${NC}"
                    return 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please select 1-3${NC}"
                    ;;
            esac
        done
    fi
    
    echo -e "${YELLOW}Available Models:${NC}"
    echo -e "${GREEN}1. gaianet/phi-3-mini-instruct-4k_paris:cuda12${NC}"
    echo -e "${GREEN}2. gaianet/qwen2-0.5b-instruct_rustlang${NC}"
    echo -e "${GREEN}3. gaianet/llama-3-8b-instruct_paris:cuda12${NC}"
    echo -e "${GREEN}4. gaianet/llama-3-8b-instruct:cuda12${NC}"
    echo -e "${GREEN}5. gaianet/llama-3.1-8b-instruct_rustlang${NC}\n"
    
    read -p "Please select a model number (1-5) [Default: 1]: " model_choice
    
    case $model_choice in
        1|"")
            MODEL="gaianet/phi-3-mini-instruct-4k_paris:cuda12"
            ;;
        2)
            MODEL="gaianet/qwen2-0.5b-instruct_rustlang"
            ;;
        3)
            MODEL="gaianet/llama-3-8b-instruct_paris:cuda12"
            ;;
        4)
            MODEL="gaianet/llama-3-8b-instruct:cuda12"
            ;;
        5)
            MODEL="gaianet/llama-3.1-8b-instruct_rustlang"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice, using default model.${NC}"
            MODEL="gaianet/phi-3-mini-instruct-4k_paris:cuda12"
            ;;
    esac
    
    echo -e "\n${GREEN}Selected model: $MODEL${NC}"
    echo -e "${BLUE}Starting Docker installation...${NC}\n"
    
    docker run -d --name gaianet \
        --gpus all \
        -p 8080:8080 \
        -v $(pwd)/qdrant_storage:/root/gaianet/qdrant/storage:z \
        $MODEL
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Gaia installation completed successfully!${NC}"
        echo -e "${BLUE}Waiting for container to initialize...${NC}"
        sleep 5
        docker logs gaianet
        
        # Ask about nodeid restoration after fresh installation
        restore_nodeid
    else
        echo -e "${RED}Error during Gaia installation${NC}"
        return 1
    fi
}

# Function to get Gaia information
get_gaia_info() {
    echo -e "${BLUE}Getting Gaia information...${NC}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^gaianet$"; then
        echo -e "${RED}Gaia container is not running. Please start it first.${NC}"
        return 1
    fi
    
    docker exec -it gaianet /root/gaianet/bin/gaianet info
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully retrieved Gaia information!${NC}"
    else
        echo -e "${RED}Error getting Gaia information${NC}"
        return 1
    fi
}

# Function to get GaiaNet address
get_gaianet_address() {
    echo -e "${BLUE}Getting GaiaNet address from Docker logs...${NC}"
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${BLUE}Attempt $attempt of $max_attempts to get GaiaNet address...${NC}"
        ADDRESS=$(docker logs gaianet 2>&1 | grep "GaiaNet node is started at:" | grep -o "0x[a-fA-F0-9]\{40\}" | tail -n 1)
        
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

# Function to get model name
get_model_name() {
    echo -e "${BLUE}Extracting model name from Docker logs...${NC}"
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${BLUE}Attempt $attempt of $max_attempts to get model name...${NC}"
        MODEL_NAME=$(docker logs gaianet 2>&1 | grep "wasmedge --dir" | grep -o "model-name [^,]*" | cut -d' ' -f2)
        
        if [ -n "$MODEL_NAME" ]; then
            echo -e "${GREEN}Successfully found model name: ${MODEL_NAME}${NC}"
            return 0
        else
            echo -e "${YELLOW}Model name not found yet, waiting 10 seconds...${NC}"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}Failed to get model name after $max_attempts attempts${NC}"
    return 1
}

# Function to install requirements
install_requirements() {
    if [ ! -f "requirements.txt" ]; then
        echo -e "${RED}requirements.txt not found in current directory!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Installing Python requirements...${NC}"
    if ! pip install -r requirements.txt; then
        echo -e "${YELLOW}Standard installation failed, trying with --break-system-packages...${NC}"
        if ! pip install --break-system-packages -r requirements.txt; then
            echo -e "${RED}Failed to install requirements even with --break-system-packages.${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to setup bot
setup_bot() {
    echo -e "${BLUE}Setting up Gaia bot...${NC}"
    
    if ! get_gaianet_address; then
        echo -e "${RED}Failed to get GaiaNet address. Bot setup aborted.${NC}"
        echo -e "${RED}Please ensure Gaia is running properly and try again.${NC}"
        return 1
    fi
    
    if ! get_model_name; then
        echo -e "${RED}Failed to get model name. Bot setup aborted.${NC}"
        echo -e "${RED}Please ensure Gaia is running properly and try again.${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Proceeding with bot setup using address: ${ADDRESS}${NC}"
    echo -e "${BLUE}Using model name: ${MODEL_NAME}${NC}"
    
    if [ -d "Gaianet-API-Bot" ]; then
        echo -e "${YELLOW}Gaianet-API-Bot directory already exists. Removing it...${NC}"
        rm -rf Gaianet-API-Bot
    fi
    
    if ! git clone https://github.com/afiq-haekal/Gaianet-API-Bot.git; then
        echo -e "${RED}Failed to clone repository. Bot setup aborted.${NC}"
        return 1
    fi
    
    cd Gaianet-API-Bot || {
        echo -e "${RED}Failed to enter project directory. Bot setup aborted.${NC}"
        return 1
    }
    
    if [ -f "sample.env" ]; then
        # Create new .env with updated values
        echo "API_URL=https://${ADDRESS}.us.gaianet.network/v1/chat/completions" > .env
        echo "MODEL=Meta-Llama-3-8B-Instruct-Q5_K_M" >> .env
        echo "DISCORD_WEBHOOK_URL=" >> .env
        
        echo -e "${GREEN}Successfully created and updated .env file${NC}"
        
        configure_discord_webhook
    else
        echo -e "${RED}sample.env not found! Bot setup aborted.
        return 1
    fi
    
    if ! install_requirements; then
        echo -e "${RED}Failed to install requirements. Bot setup aborted.${NC}"
        return 1
    fi
    
    while true; do
        read -p "Do you want to start the bot now? (y/n): " yn
        case $yn in
            [Yy]* )
                echo -e "${BLUE}Starting the bot with nohup...${NC}"
                nohup python3 main.py > bot.log 2>&1 &
                PID=$!
                
                if ps -p $PID > /dev/null; then
                    echo -e "${GREEN}Bot started successfully with PID: $PID${NC}"
                    echo -e "${GREEN}Bot logs can be found in bot.log${NC}"
                else
                    echo -e "${RED}Failed to start the bot.${NC}"
                    return 1
                fi
                break
                ;;
            [Nn]* )
                echo -e "${BLUE}Bot setup completed. You can start it later using:${NC}"
                echo -e "${GREEN}cd Gaianet-API-Bot && nohup python3 main.py > bot.log 2>&1 &${NC}"
                break
                ;;
            * )
                echo "Please answer yes (y) or no (n)"
                ;;
        esac
    done
    
    return 0
}

# Main menu function
show_menu() {
    clear  # Clear screen before showing menu
    echo -e "\n${BLUE}=== Gaia Installation and Setup Menu ===${NC}"
    echo "1. Install Gaia"
    echo "2. Get Gaia Info"
    echo "3. Setup Gaia Bot"
    echo "4. Exit"
    echo -e "${BLUE}======================================${NC}\n"
}

# Main program loop
main() {
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
}

# Start the program
main
