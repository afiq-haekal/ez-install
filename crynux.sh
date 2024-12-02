#!/bin/bash


mkdir -p crynux

cd crynux

# Create "docker-compose.yml" file with content
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

# Display clear message about file creation and docker-compose command usage
echo "docker-compose.yml file created successfully!"
echo "To start the Docker containers in detached mode, run:"
echo "docker compose up -d"

# Optional: Prompt user to run the command
read -p "Run docker-compose up -d now? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  docker-compose up -d
  echo "Crynux Node containers started in detached mode."
fi
