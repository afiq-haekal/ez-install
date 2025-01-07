#!/bin/bash

# Set log directory
LOG_DIR="/var/log/ai_services"
OLLAMA_LOG="${LOG_DIR}/ollama.log"
INFERA_LOG="${LOG_DIR}/infera.log"
PID_DIR="/var/run/ai_services"
INFERA_PATH="/root/infera"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Function to check CPU manufacturer
check_cpu() {
    if lscpu | grep -q "GenuineIntel"; then
        echo "intel"
    elif lscpu | grep -q "AMD"; then
        echo "amd"
    else
        echo "unknown"
        exit 1
    fi
}

# Function to create necessary directories
setup_directories() {
    echo -e "${BLUE}Setting up directories...${NC}"
    mkdir -p "$LOG_DIR"
    mkdir -p "$PID_DIR"
    chmod 755 "$LOG_DIR"
    chmod 755 "$PID_DIR"
}

# Function to install Ollama
install_ollama() {
    echo -e "${BLUE}Installing Ollama...${NC}"
    curl -L https://ollama.com/download/ollama-linux-amd64.tgz -o ollama-linux-amd64.tgz
    sudo tar -C /usr -xzf ollama-linux-amd64.tgz
    rm ollama-linux-amd64.tgz
    echo -e "${GREEN}Ollama installation completed${NC}"
}

# Function to install Infera
install_infera() {
    local cpu_type=$1
    echo -e "${BLUE}Installing Infera for ${cpu_type}...${NC}"
    
    if [ "$cpu_type" = "intel" ]; then
        curl -sSL http://downloads.infera.org/infera-linux-intel.sh | bash
    else
        curl -sSL http://downloads.infera.org/infera-linux-amd.sh | bash
    fi
    
    chmod +x "$INFERA_PATH"
    echo "export PATH=\$PATH:/root" >> /root/.bashrc
    source /root/.bashrc
    echo -e "${GREEN}Infera installation completed${NC}"
}

# Function to show logs
show_logs() {
    local service=$1
    local log_file
    
    case $service in
        "ollama")
            log_file="$OLLAMA_LOG"
            ;;
        "infera")
            log_file="$INFERA_LOG"
            ;;
        *)
            echo -e "${RED}Invalid service${NC}"
            return
            ;;
    esac
    
    echo -e "${YELLOW}Showing last 50 lines of $service log. Press Ctrl+C to exit${NC}"
    tail -f -n 50 "$log_file"
}

# Function to start services
start_service() {
    local service=$1
    
    case $service in
        "ollama")
            nohup ollama serve > "$OLLAMA_LOG" 2>&1 &
            echo $! > "${PID_DIR}/ollama.pid"
            echo -e "${GREEN}Ollama started with PID $(cat ${PID_DIR}/ollama.pid)${NC}"
            ;;
        "infera")
            if [ -f "$INFERA_PATH" ]; then
                nohup "$INFERA_PATH" > "$INFERA_LOG" 2>&1 &
                echo $! > "${PID_DIR}/infera.pid"
                echo -e "${GREEN}Infera started with PID $(cat ${PID_DIR}/infera.pid)${NC}"
            else
                echo -e "${RED}Error: Infera executable not found at $INFERA_PATH${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid service${NC}"
            ;;
    esac
}

# Function to stop services
stop_service() {
    local service=$1
    local pid_file="${PID_DIR}/${service}.pid"
    
    if [ -f "$pid_file" ]; then
        kill $(cat "$pid_file") 2>/dev/null
        rm "$pid_file"
        echo -e "${GREEN}${service^} stopped${NC}"
    else
        echo -e "${YELLOW}${service^} is not running${NC}"
    fi
}

# Interactive menu
show_menu() {
    clear
    echo -e "${BLUE}=== AI Services Management ===${NC}"
    echo "1. Install Services"
    echo "2. Service Management"
    echo "3. View Logs"
    echo "4. Exit"
    echo
    read -p "Select an option (1-4): " choice

    case $choice in
        1)
            show_install_menu
            ;;
        2)
            show_service_menu
            ;;
        3)
            show_logs_menu
            ;;
        4)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

show_install_menu() {
    clear
    echo -e "${BLUE}=== Installation Menu ===${NC}"
    echo "1. Install Both Services"
    echo "2. Install Ollama Only"
    echo "3. Install Infera Only"
    echo "4. Back to Main Menu"
    echo
    read -p "Select an option (1-4): " choice

    case $choice in
        1)
            setup_directories
            CPU_TYPE=$(check_cpu)
            install_ollama
            install_infera "$CPU_TYPE"
            read -p "Press Enter to continue..."
            show_menu
            ;;
        2)
            setup_directories
            install_ollama
            read -p "Press Enter to continue..."
            show_menu
            ;;
        3)
            setup_directories
            CPU_TYPE=$(check_cpu)
            install_infera "$CPU_TYPE"
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            show_menu
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            show_install_menu
            ;;
    esac
}

show_service_menu() {
    clear
    echo -e "${BLUE}=== Service Management ===${NC}"
    echo "1. Start Ollama"
    echo "2. Stop Ollama"
    echo "3. Start Infera"
    echo "4. Stop Infera"
    echo "5. Start Both Services"
    echo "6. Stop Both Services"
    echo "7. Back to Main Menu"
    echo
    read -p "Select an option (1-7): " choice

    case $choice in
        1)
            start_service "ollama"
            ;;
        2)
            stop_service "ollama"
            ;;
        3)
            start_service "infera"
            ;;
        4)
            stop_service "infera"
            ;;
        5)
            start_service "ollama"
            start_service "infera"
            ;;
        6)
            stop_service "ollama"
            stop_service "infera"
            ;;
        7)
            show_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            show_service_menu
            ;;
    esac
    
    read -p "Press Enter to continue..."
    show_service_menu
}

show_logs_menu() {
    clear
    echo -e "${BLUE}=== View Logs ===${NC}"
    echo "1. View Ollama Logs"
    echo "2. View Infera Logs"
    echo "3. Back to Main Menu"
    echo
    read -p "Select an option (1-3): " choice

    case $choice in
        1)
            show_logs "ollama"
            ;;
        2)
            show_logs "infera"
            ;;
        3)
            show_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            show_logs_menu
            ;;
    esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Start the menu
show_menu
