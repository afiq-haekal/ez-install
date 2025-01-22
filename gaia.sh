#!/bin/bash

# Function to configure Discord webhook
configure_discord_webhook() {
    echo "Discord Webhook Configuration"
    echo "The webhook URL should look like: https://discord.com/api/webhooks/ID/TOKEN"
    
    while true; do
        read -p "Enter your Discord webhook URL (or press Enter to skip): " webhook_url
        
        if [ -z "$webhook_url" ]; then
            echo "Skipping Discord webhook configuration"
            return 0
        fi
        
        if [[ $webhook_url == https://discordapp.com/api/webhooks/* ]] || [[ $webhook_url == https://discord.com/api/webhooks/* ]]; then
            if grep -q "DISCORD_WEBHOOK_URL=" .env; then
                sed -i "s#DISCORD_WEBHOOK_URL=.*#DISCORD_WEBHOOK_URL=$webhook_url#" .env
            else
                echo "DISCORD_WEBHOOK_URL=$webhook_url" >> .env
            fi
            echo "Discord webhook URL configured successfully!"
            return 0
        else
            echo "Invalid webhook URL format. Please enter a valid Discord webhook URL"
            read -p "Try again? (y/n): " retry
            if [[ $retry != [Yy]* ]]; then
                echo "Skipping Discord webhook configuration"
                return 0
            fi
        fi
    done
}

# Function to restore nodeid
restore_nodeid() {
    echo "Restore NodeID Configuration"
    
    while true; do
        read -p "Do you want to restore a nodeid.json file? (y/n): " restore_choice
        
        case $restore_choice in
            [Yy]*)
                read -p "Enter the path to your nodeid.json file: " nodeid_path
                
                if [ -f "$nodeid_path" ]; then
                    if docker cp "$nodeid_path" gaianet:/root/gaianet/nodeid.json; then
                        echo "Successfully restored nodeid.json"
                        echo "Restarting container to apply changes..."
                        if docker restart gaianet; then
                            echo "Container restarted successfully!"
                            docker logs gaianet --since 0m > /dev/null 2>&1
                            sleep 5
                            return 0
                        else
                            echo "Failed to restart container"
                            return 1
                        fi
                    else
                        echo "Failed to copy nodeid.json to container"
                        read -p "Try again? (y/n): " retry
                        if [[ $retry != [Yy]* ]]; then
                            return 1
                        fi
                    fi
                else
                    echo "File not found: $nodeid_path"
                    read -p "Try again? (y/n): " retry
                    if [[ $retry != [Yy]* ]]; then
                        return 1
                    fi
                fi
                ;;
            [Nn]*)
                echo "Skipping nodeid.json restoration"
                return 0
                ;;
            *)
                echo "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Function to check Docker installation
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "Docker daemon is not running. Please start Docker service."
        exit 1
    fi
}

# Function to check Git installation
check_git() {
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Please install Git first."
        exit 1
    fi
}

# Function to check Python installation
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Installing Python3..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y python3
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y python3
        else
            echo "Unsupported distribution. Please install Python3 manually."
            exit 1
        fi
    fi

    if ! command -v pip &> /dev/null; then
        echo "pip is not installed. Installing pip..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get install -y python3-pip
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y python3-pip
        else
            echo "Unsupported distribution. Please install pip manually."
            exit 1
        fi
    fi
}

# Function to install Gaia
install_gaia() {
    clear
    echo "Installing Gaia via Docker"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^gaianet$"; then
        echo "Existing 'gaianet' container detected"
        echo "1. Stop and remove existing container"
        echo "2. Restart existing container"
        echo "3. Abort installation"
        
        while true; do
            read -p "Please select an option (1-3): " container_choice
            
            case $container_choice in
                1)
                    echo "Stopping and removing existing container..."
                    docker stop gaianet
                    docker rm gaianet
                    break
                    ;;
                2)
                    echo "Restarting existing container..."
                    docker restart gaianet
                    echo "Container restarted successfully!"
                    docker logs gaianet --since 0m > /dev/null 2>&1
                    sleep 5
                    restore_nodeid
                    return 0
                    ;;
                3)
                    echo "Installation aborted"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please select 1-3"
                    ;;
            esac
        done
    fi
    
    echo "Available Models:"
    echo "1. gaianet/phi-3-mini-instruct-4k_paris:cuda12"
    echo "2. gaianet/qwen2-0.5b-instruct_rustlang"
    echo "3. gaianet/llama-3-8b-instruct_paris:cuda12"
    echo "4. gaianet/llama-3-8b-instruct:cuda12"
    echo "5. gaianet/llama-3.1-8b-instruct_rustlang"
    
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
            echo "Invalid choice, using default model."
            MODEL="gaianet/phi-3-mini-instruct-4k_paris:cuda12"
            ;;
    esac
    
    echo "Selected model: $MODEL"
    echo "Starting Docker installation..."
    
    docker run -d --name gaianet \
        --gpus all \
        -p 8080:8080 \
        -v $(pwd)/qdrant_storage:/root/gaianet/qdrant/storage:z \
        $MODEL
    
    if [ $? -eq 0 ]; then
        echo "Gaia installation completed successfully!"
        echo "Waiting for container to initialize..."
        sleep 5
        docker logs gaianet
        restore_nodeid
    else
        echo "Error during Gaia installation"
        return 1
    fi
}

# Function to get Gaia information
get_gaia_info() {
    echo "Getting Gaia information..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^gaianet$"; then
        echo "Gaia container is not running. Please start it first."
        return 1
    fi
    
    docker exec -it gaianet /root/gaianet/bin/gaianet info
    
    if [ $? -eq 0 ]; then
        echo "Successfully retrieved Gaia information!"
    else
        echo "Error getting Gaia information"
        return 1
    fi
}

# Function to get GaiaNet address
get_gaianet_address() {
    echo "Getting GaiaNet address from Docker logs..."
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts to get GaiaNet address..."
        ADDRESS=$(docker logs gaianet 2>&1 | grep "GaiaNet node is started at:" | grep -o "0x[a-fA-F0-9]\{40\}" | tail -n 1)
        
        if [ -n "$ADDRESS" ]; then
            echo "Successfully found GaiaNet address: ${ADDRESS}"
            return 0
        else
            echo "Address not found yet, waiting 10 seconds..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Failed to get GaiaNet address after $max_attempts attempts"
    return 1
}

# Function to get model name
get_model_name() {
    echo "Extracting model name from Docker logs..."
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts to get model name..."
        MODEL_NAME=$(docker logs gaianet 2>&1 | grep "wasmedge --dir" | grep -o "model-name [^,]*" | cut -d' ' -f2)
        
        if [ -n "$MODEL_NAME" ]; then
            echo "Successfully found model name: ${MODEL_NAME}"
            return 0
        else
            echo "Model name not found yet, waiting 10 seconds..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Failed to get model name after $max_attempts attempts"
    return 1
}

# Function to install requirements
install_requirements() {
    if [ ! -f "requirements.txt" ]; then
        echo "requirements.txt not found in current directory!"
        return 1
    fi
    
    echo "Installing Python requirements..."
    if ! pip install -r requirements.txt; then
        echo "Standard installation failed, trying with --break-system-packages..."
        if ! pip install --break-system-packages -r requirements.txt; then
            echo "Failed to install requirements even with --break-system-packages."
            return 1
        fi
    fi
    return 0
}

# Function to setup bot
setup_bot() {
    echo "Setting up Gaia bot..."
    
    if ! get_gaianet_address; then
        echo "Failed to get GaiaNet address. Bot setup aborted."
        echo "Please ensure Gaia is running properly and try again."
        return 1
    fi
    
    if ! get_model_name; then
        echo "Failed to get model name. Bot setup aborted."
        echo "Please ensure Gaia is running properly and try again."
        return 1
    fi
    
    echo "Proceeding with bot setup using address: ${ADDRESS}"
    echo "Using model name: ${MODEL_NAME}"
    
    if [ -d "Gaianet-API-Bot" ]; then
        echo "Gaianet-API-Bot directory already exists. Removing it..."
        rm -rf Gaianet-API-Bot
    fi
    
    if ! git clone https://github.com/afiq-haekal/Gaianet-API-Bot.git; then
        echo "Failed to clone repository. Bot setup aborted."
        return 1
    fi
    
    cd Gaianet-API-Bot || {
        echo "Failed to enter project directory. Bot setup aborted."
        return 1
    }
    
    if [ -f "sample.env" ]; then
        echo "API_URL=https://${ADDRESS}.us.gaianet.network/v1/chat/completions" > .env
        echo "MODEL=Meta-Llama-3-8B-Instruct-Q5_K_M" >> .env
        echo "DISCORD_WEBHOOK_URL=" >> .env
        
        echo "Successfully created and updated .env file"
        
        configure_discord_webhook
    else
        echo "sample.env not found! Bot setup aborted."
        return 1
    fi
    
    if ! install_requirements; then
        echo "Failed to install requirements. Bot setup aborted."
        return 1
    fi
    
    while true
    do
        read -p "Do you want to start the bot now? (y/n): " yn
        case "$yn" in
            [Yy]*)
                echo "Starting the bot with nohup..."
                nohup python3 main.py > bot.log 2>&1 &
                PID=$!
                
                if ps -p $PID > /dev/null; then
                    echo "Bot started successfully with PID: $PID"
                    echo "Bot logs can be found in bot.log"
                else
                    echo "Failed to start the bot."
                    return 1
                fi
                break
                ;;
            [Nn]*)
                echo "Bot setup completed. You can start it later using:"
                echo "cd Gaianet-API-Bot && nohup python3 main.py > bot.log 2>&1 &"
                break
                ;;
            *)
                echo "Please answer yes (y) or no (n)"
                ;;
        esac
    done
    
    return 0
}

# Menu function
show_menu() {
    clear
    echo "=== Gaia Installation and Setup Menu ==="
    echo "1. Install Gaia"
    echo "2. Get Gaia Info"
    echo "3. Setup Gaia Bot"
    echo "4. Exit"
    echo "======================================"
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
                echo "Exiting the installer. Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Please select 1-4"
                ;;
        esac
        
        echo "Press Enter to continue..."
        read
    done
}

# Start the program
main
