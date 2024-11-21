#!/bin/bash

# Check if running with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# GPU Type Selection
echo "Select GPU type:"
echo "1. NVIDIA"
echo "2. AMD"
read -p "Enter choice (1/2): " GPU_CHOICE

# Set miner URL and filename based on GPU type
if [ "$GPU_CHOICE" = "1" ]; then
    MINER_URL="https://github.com/6block/zkwork_moz_prover/releases/download/v1.0.2/moz_prover-v1.0.2_cuda.tar.gz"
    MINER_FILE="moz_prover-v1.0.2_cuda.tar.gz"
elif [ "$GPU_CHOICE" = "2" ]; then
    MINER_URL="https://github.com/6block/zkwork_moz_prover/releases/download/v1.0.2/moz_prover-v1.0.2_ocl.tar.gz"
    MINER_FILE="moz_prover-v1.0.2_ocl.tar.gz"
else
    echo "Invalid choice"
    exit 1
fi

# Download miner
echo "Downloading miner..."
wget "$MINER_URL"

# Extract miner
tar -zvxf "$MINER_FILE"
cd moz_prover

# Configuration
read -p "Enter reward address: " REWARD_ADDRESS
read -p "Enter custom name: " CUSTOM_NAME

# Create/update inner_prover.sh
cat > inner_prover.sh << EOL
#!/bin/bash

# use your own Lumoz reward_address
reward_address=$REWARD_ADDRESS
# set your own custom name
custom_name="$CUSTOM_NAME"
pids=\$(ps -ef | grep moz_prover | grep -v grep | awk '{print \$2}')
if [ -n "\$pids" ]; then
    echo "\$pids" | xargs kill
    sleep 5
fi
while true; do
    target=\`ps aux | grep moz_prover | grep -v grep\`
    if [ -z "\$target" ]; then
        ./moz_prover --mozaddress \$reward_address --lumozpool moz.asia.zk.work:10010 --custom_name "\$custom_name"
        sleep 5
    fi
    sleep 60
done
EOL

# Set permissions
chmod +x inner_prover.sh run_prover.sh

# Start mining
./run_prover.sh
