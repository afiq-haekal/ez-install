#!/bin/bash

# Prompt for wallet address
echo "Please enter your wallet address (press Enter to use default: 0xDEAF249138363a20703E0FA7e10Dfb06039D168f):"
read wallet_address

# If no input, use default address
if [ -z "$wallet_address" ]; then
    wallet_address="0xDEAF249138363a20703E0FA7e10Dfb06039D168f"
fi

# Prompt for worker name
echo "Please enter worker name (press Enter to use default: Worker001):"
read worker_name

# If no input, use default worker name
if [ -z "$worker_name" ]; then
    worker_name="Worker001"
fi

# Download the miner
echo "Downloading IniMiner..."
wget https://github.com/Project-InitVerse/miner/releases/download/v1.0.0/iniminer-linux-x64

# Make it executable
echo "Setting executable permissions..."
chmod +x iniminer-linux-x64

# Run the miner
echo "Starting the miner with address: $wallet_address and worker: $worker_name"
./iniminer-linux-x64 --pool stratum+tcp://${wallet_address}.${worker_name}@pool-core-testnet.inichain.com:32672
