#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker container status
check_docker_container() {
    # Check if docker is installed
    if ! command_exists docker; then
        echo "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if docker service is running
    if ! systemctl is-active --quiet docker; then
        echo "Docker service is not running. Starting Docker service..."
        sudo systemctl start docker
        sleep 3
    fi

    # Check if crynux container exists and is running
    if [ "$(docker ps -q -f name=crynux_node)" ]; then
        echo -e "\nCrynux Node container is already running"
        echo "Choose an option:"
        echo "1) New installation (will remove existing container)"
        echo "2) Skip to monitoring only"
        echo "3) Cancel operation"
        
        while true; do
            read -p "Enter your choice (1-3): " choice
            case "$choice" in 
                1)
                    echo "Stopping and removing existing container..."
                    docker stop crynux_node
                    docker rm crynux_node
                    return 0
                    ;;
                2)
                    echo "Skipping installation, proceeding to monitoring setup..."
                    return 1
                    ;;
                3)
                    echo "Operation cancelled"
                    exit 1
                    ;;
                *)
                    echo "Invalid option. Please choose 1, 2, or 3"
                    ;;
            esac
        done
    fi
    return 0
}

# Function to check monitor installation
check_monitor_installation() {
    if [ -f "/etc/systemd/system/crynux-monitor.service" ]; then
        echo -e "\nCrynux Monitor service is already installed"
        echo "Choose an option:"
        echo "1) Reinstall monitoring service"
        echo "2) Skip monitor installation"
        echo "3) Cancel operation"
        
        while true; do
            read -p "Enter your choice (1-3): " choice
            case "$choice" in 
                1)
                    echo "Stopping and removing existing monitor service..."
                    sudo systemctl stop crynux-monitor
                    sudo systemctl disable crynux-monitor
                    sudo rm /etc/systemd/system/crynux-monitor.service
                    return 0
                    ;;
                2)
                    echo "Skipping monitor installation..."
                    return 1
                    ;;
                3)
                    echo "Operation cancelled"
                    exit 1
                    ;;
                *)
                    echo "Invalid option. Please choose 1, 2, or 3"
                    ;;
            esac
        done
    fi
    return 0
}

# Function to check and install Python dependencies
setup_python() {
    local python_installed=false
    local pip_installed=false

    # Check Python3
    if command_exists python3; then
        echo "Python3 is installed"
        python_installed=true
    else
        echo "Python3 is not installed"
    fi

    # Check pip
    if command_exists pip3; then
        echo "pip3 is installed"
        pip_installed=true
    else
        echo "pip3 is not installed"
    fi

    # Install missing components
    if [ "$python_installed" = false ] || [ "$pip_installed" = false ]; then
        echo "Installing missing Python components..."
        sudo apt-get update
        
        if [ "$python_installed" = false ]; then
            sudo apt-get install -y python3
        fi
        
        if [ "$pip_installed" = false ]; then
            sudo apt-get install -y python3-pip
        fi
    fi

    # Verify installation
    if ! command_exists python3 || ! command_exists pip3; then
        echo "Failed to install Python components"
        exit 1
    fi
    
    echo "Installing required Python packages..."
    pip3 install --upgrade pip
    pip3 install discord-webhook python-dateutil requests
}

# Create Python monitoring script
create_python_monitor() {
    cat << 'EOF' > monitor.py
import json
import subprocess
import re
from datetime import datetime
from discord_webhook import DiscordWebhook, DiscordEmbed
import time
import requests

class CrynuxMonitor:
    def __init__(self, webhook_url):
        self.webhook_url = webhook_url
        self.inference_count = 0
        self.wallet_address = ""
        self.public_ip = self.get_public_ip()

    def get_public_ip(self):
        try:
            response = requests.get('https://api.ipify.org')
            return response.text
        except:
            return "Unable to get IP"

    def send_discord_message(self, title, description, color):
        webhook = DiscordWebhook(url=self.webhook_url)
        embed = DiscordEmbed(
            title=title,
            description=description,
            color=color
        )
        if self.wallet_address:
            description = f"Wallet: {self.wallet_address}\nIP: {self.public_ip}\n{description}"
        embed.description = description
        embed.set_footer(text=f'Total Successful Inference Tasks: {self.inference_count}')
        embed.set_timestamp()
        webhook.add_embed(embed)
        webhook.execute()

    def process_log_line(self, line):
        try:
            # Extract timestamp and message
            timestamp_match = re.search(r'\[(.*?)\]', line)
            if not timestamp_match:
                return

            # Wallet Address Detection
            if "Wallet address is" in line:
                wallet_match = re.search(r'0x[a-fA-F0-9]{40}', line)
                if wallet_match:
                    self.wallet_address = wallet_match.group(0)
                    self.send_discord_message(
                        "Wallet Address Detected",
                        f"New wallet detected",
                        5814783  # Blue
                    )

            # Node Join Success
            elif "Node joins in the network successfully" in line:
                self.send_discord_message(
                    "Node Status",
                    "Node has successfully joined the network",
                    3066993  # Green
                )

            # Start Inference Task
            elif "Start inference task" in line:
                self.send_discord_message(
                    "Task Started",
                    "New inference task has started",
                    15844367  # Purple
                )

            # Inference Success
            elif "Inference task success" in line:
                self.inference_count += 1
                self.send_discord_message(
                    "Task Success",
                    "Inference task completed successfully",
                    3066993  # Green
                )

            # Error Detection
            elif "[ERROR" in line:
                self.send_discord_message(
                    "Error Detected",
                    line,
                    15158332  # Red
                )

        except Exception as e:
            print(f"Error processing log line: {e}")

    def monitor_logs(self):
        process = subprocess.Popen(
            ['docker', 'logs', '-f', 'crynux_node'],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True
        )

        while True:
            line = process.stdout.readline()
            if not line:
                break
            self.process_log_line(line.strip())

def main():
    with open('config.json', 'r') as f:
        config = json.load(f)
    
    monitor = CrynuxMonitor(config['webhook_url'])
    print("Starting Crynux Node monitoring...")
    monitor.monitor_logs()

if __name__ == "__main__":
    main()
EOF
}

# Main script execution starts here
mkdir -p crynux
cd crynux

# Check Docker container and get user choice first
echo "Checking Docker container status..."
check_docker_container
proceed_with_install=$?

# Then check Monitor installation
echo "Checking monitor installation..."
check_monitor_installation
proceed_with_monitor=$?

# Setup Python and dependencies
echo "Checking Python dependencies..."
setup_python

if [ $proceed_with_install -eq 0 ]; then
    # Create docker-compose.yml
    cat << EOF > docker-compose.yml
---
version: "3.8"
name: "crynux_node"
services:
  crynux_node:
    image: ghcr.io/crynux-ai/crynux-node:latest
    container_name: crynux_node
    restart: unless-stopped
    ports:
      - "0.0.0.0:7412:7412"
    volumes:
      - "./tmp:/app/tmp"
      - "./config:/app/config"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
EOF
    echo "docker-compose.yml created successfully!"
    
    # Start the container
    echo "Starting Crynux Node container..."
    docker compose up -d
fi

if [ $proceed_with_monitor -eq 0 ]; then
    # Create Python monitor script
    create_python_monitor

    # Create systemd service for monitoring
    cat << EOF > /etc/systemd/system/crynux-monitor.service
[Unit]
Description=Crynux Node Monitor
After=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 $(pwd)/monitor.py
Restart=always
User=$USER
WorkingDirectory=$(pwd)

[Install]
WantedBy=multi-user.target
EOF

    # Create configuration file
    echo "Please enter your Discord webhook URL:"
    read webhook_url
    cat << EOF > config.json
{
    "webhook_url": "$webhook_url"
}
EOF

    # Start monitoring service
    echo "Starting monitoring service..."
    sudo systemctl daemon-reload
    sudo systemctl enable crynux-monitor
    sudo systemctl start crynux-monitor
    echo "Monitoring service started successfully"
    echo "To check monitor status: sudo systemctl status crynux-monitor"
    echo "To view monitor logs: sudo journalctl -u crynux-monitor -f"
fi

# Display access information
echo -e "\nAccess Information:"
echo "===================="
ip addr show | grep "inet " | grep -v "127.0.0.1" | grep -v "docker" | grep -v "br-" | awk '{print $2}' | cut -d/ -f1 | while read -r ip; do
    echo "http://$ip:7412"
done
echo "http://localhost:7412"
