#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set the output file for storing container data
OUTPUT_FILE="network3_containers_data.txt"

# Function to print colored output
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
is_port_in_use() {
    netstat -tln | grep -q ":$1 "
}

# Function to get public IP
get_public_ip() {
    curl -s ifconfig.me
}

# Function to save container data
save_container_data() {
    local container_name=$1
    local port=$2
    local key=$3
    local public_ip=$4
    
    echo "========== $container_name ==========" >> "$OUTPUT_FILE"
    echo "Container Name: $container_name" >> "$OUTPUT_FILE"
    echo "Port: $port" >> "$OUTPUT_FILE"
    echo "Node Key: $key" >> "$OUTPUT_FILE"
    echo "Registration URL: http://account.network3.ai:8080/main?o=$public_ip:$port" >> "$OUTPUT_FILE"
    echo "----------------------------------------" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Install required packages
print_message "Checking and installing required packages..."
if ! command_exists netstat; then
    print_message "Installing net-tools..."
    apt update
    apt install net-tools -y
fi

# Install Docker if not installed
if ! command_exists docker; then
    print_message "Installing Docker..."
    apt update
    apt install docker.io -y
    systemctl start docker
    systemctl enable docker
fi

# Create or clear the output file
echo "Network3 Containers Data" > "$OUTPUT_FILE"
echo "Created on: $(date)" >> "$OUTPUT_FILE"
echo "----------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to get valid port number from user
get_valid_port() {
    local port
    while true; do
        read -p "Enter port number for container $1 (1024-65535): " port
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
            if is_port_in_use "$port"; then
                print_error "Port $port is already in use. Please choose a different port."
            else
                echo "$port"
                return 0
            fi
        else
            print_error "Please enter a valid port number between 1024 and 65535"
        fi
    done
}

# Function to create and setup container
setup_container() {
    local container_number=$1
    local container_name="network3-$container_number"

    print_message "Setting up container $container_number"
    
    # Get port from user
    print_message "Port selection for $container_name"
    local port=$(get_valid_port "$container_number")
    
    # Check if container already exists
    if docker ps -a | grep -q "$container_name"; then
        print_warning "Container $container_name already exists. Removing it..."
        docker rm -f "$container_name"
    fi

    print_message "Creating container $container_name on port $port..."
    docker run -d -it -p $port:8080 -v /sys:/sys --privileged --name "$container_name" ubuntu:22.04

    print_message "Setting up Network3 in container $container_name..."
    docker exec -i "$container_name" bash <<EOF
apt update && apt upgrade -y
apt install wget net-tools iproute2 iptables -y
wget https://network3.io/ubuntu-node-v2.1.0.tar
tar -xvf ubuntu-node-v2.1.0.tar
cd ubuntu-node
bash manager.sh up
key=\$(bash manager.sh key)
echo "\$key" > /root/node_key.txt
EOF

    # Get the key from the container
    key=$(docker exec "$container_name" cat /root/node_key.txt)
    public_ip=$(get_public_ip)

    # Save container data to file
    save_container_data "$container_name" "$port" "$key" "$public_ip"

    print_message "Container $container_name setup complete!"
    echo "----------------------------------------"
    echo "Container Name: $container_name"
    echo "Port: $port"
    echo "Node Key: $key"
    echo "Registration URL: http://account.network3.ai:8080/main?o=$public_ip:$port"
    echo "----------------------------------------"
}

# Main script
echo "Network3 Node Auto Installer"
echo "=========================="

read -p "How many nodes do you want to install? (max 5): " node_count

if ! [[ "$node_count" =~ ^[1-5]$ ]]; then
    print_error "Please enter a number between 1 and 5"
    exit 1
fi

for i in $(seq 1 "$node_count"); do
    print_message "Setting up node $i of $node_count"
    setup_container "$i"
done

print_message "Installation complete! All data has been saved to $OUTPUT_FILE"
print_message "You can view the data by running: cat $OUTPUT_FILE"
print_warning "Remember to register your nodes at https://account.network3.ai/login_page using Mozilla Firefox!"

# Make the output file readable only by root for security
chmod 600 "$OUTPUT_FILE"
