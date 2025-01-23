#!/bin/bash

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root (use sudo)"
        exit 1
    fi
}

# Function to check and install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    else
        echo "Docker already installed"
    fi
}

# Function to setup Ollama in Docker
setup_ollama() {
    echo "Setting up Ollama in Docker..."
    
    # Create docker-compose.yml
    cat > compose.yml << 'EOF'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama_data:/root/.ollama
    ports:
      - "11434:11434"
    restart: unless-stopped

volumes:
  ollama_data:
EOF

    # Stop and remove any existing containers
    docker compose down -v
    
    # Start Ollama container
    docker compose up -d

    # Wait for Ollama to start and become ready
    echo "Waiting for Ollama to start..."
    until curl -s http://localhost:11434/api/version > /dev/null; do
        echo "Waiting for Ollama API..."
        sleep 5
    done

    # Pull llama2 model
    echo "Pulling llama2 model..."
    curl -X POST http://localhost:11434/api/pull -d '{"name": "llama2:latest"}'
}

# Main setup process
main() {
    echo "Starting setup process..."
    
    # Check if running as root
    check_root
    
    # Stop any existing Ollama service
    systemctl stop ollama || true
    
    # Install Docker if needed
    install_docker
    
    # Setup Ollama in Docker
    setup_ollama
    
    echo "Setup completed!"
    echo "Ollama is running in Docker on port 11434"
    echo "You can check Ollama logs with: docker logs -f ollama"
    echo "Use 'docker compose logs -f' to see ongoing logs"
}

# Run main setup
main
