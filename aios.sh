#!/bin/bash

# Function to execute command with retry option
execute_command() {
    local cmd="$1"
    local max_retries=5
    local retry_count=0
    local success=false

    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        echo "Executing: $cmd"
        if eval "$cmd"; then
            success=true
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "Command failed. Attempt $retry_count of $max_retries"
                echo "Automatically retrying in 2 seconds..."
                sleep 2
            else
                echo "Maximum retry attempts reached after 5 attempts."
            fi
        fi
    done
}

# Function to clear screen and show menu
show_menu() {
    clear
    echo "================================"
    echo "     AIOS CLI Interactive Menu   "
    echo "================================"
    echo "1. Start AIOS daemon"
    echo "2. Check daemon status"
    echo "3. Kill daemon"
    echo "4. List available models"
    echo "5. List downloaded models"
    echo "6. Add new model"
    echo "7. System info"
    echo "8. Hive commands"
    echo "9. Check points"
    echo "10. Version"
    echo "0. Exit"
    echo "================================"
}

# Function for model selection menu
show_model_menu() {
    clear
    echo "================================"
    echo "       Model Selection Menu     "
    echo "================================"
    echo "1. Add default model (phi-2)"
    echo "2. Add custom model"
    echo "3. Back to main menu"
    echo "================================"
}

# Function to handle model selection
handle_model_menu() {
    while true; do
        show_model_menu
        read -p "Enter your choice (1-3): " model_choice
        case $model_choice in
            1)
                default_model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
                echo "Adding default model: $default_model"
                execute_command "aios-cli models add \"$default_model\""
                ;;
            2)
                read -p "Enter model path: " model_path
                execute_command "aios-cli models add \"$model_path\""
                ;;
            3)
                return
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Function for hive submenu
show_hive_menu() {
    clear
    echo "================================"
    echo "       Hive Commands Menu       "
    echo "================================"
    echo "1. Login"
    echo "2. Import keys"
    echo "3. Connect to network"
    echo "4. Check current keys (whoami)"
    echo "5. Disconnect"
    echo "6. Select tier"
    echo "7. Allocate GPU memory"
    echo "8. Back to main menu"
    echo "================================"
}

# Function to handle hive commands
handle_hive_menu() {
    while true; do
        show_hive_menu
        read -p "Enter your choice (1-8): " hive_choice
        case $hive_choice in
            1)
                execute_command "aios-cli hive login"
                ;;
            2)
                read -p "Enter path to key file: " key_path
                execute_command "aios-cli hive import-keys \"$key_path\""
                ;;
            3)
                execute_command "aios-cli hive connect"
                ;;
            4)
                execute_command "aios-cli hive whoami"
                ;;
            5)
                execute_command "aios-cli hive disconnect"
                ;;
            6)
                read -p "Enter tier number (1-5): " tier
                execute_command "aios-cli hive select-tier $tier"
                ;;
            7)
                read -p "Enter GPU memory amount in GB: " memory
                execute_command "aios-cli hive allocate $memory"
                ;;
            8)
                return
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice (0-10): " choice

    case $choice in
        1)
            execute_command "aios-cli start"
            ;;
        2)
            execute_command "aios-cli status"
            ;;
        3)
            execute_command "aios-cli kill"
            ;;
        4)
            execute_command "aios-cli models available"
            ;;
        5)
            execute_command "aios-cli models list"
            ;;
        6)
            handle_model_menu
            ;;
        7)
            execute_command "aios-cli system-info"
            ;;
        8)
            handle_hive_menu
            ;;
        9)
            execute_command "aios-cli hive points"
            ;;
        10)
            execute_command "aios-cli version"
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    read -p "Press Enter to continue..."
done
