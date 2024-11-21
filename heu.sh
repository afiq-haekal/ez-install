#!/bin/bash

set -e  

EVM_ADDRESS="0xDEAF249138363a20703E0FA7e10Dfb06039D168f"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fungsi untuk log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fungsi persiapan sistem
prepare_system() {
    log_info "🔧 Mempersiapkan sistem..."
    
    # Update dan upgrade sistem
    sudo apt update && sudo apt upgrade -y
    
    # Instalasi software-properties-common
    sudo apt install -y software-properties-common
    
    # Tambah repository Python
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    
    # Update kembali setelah menambah repository
    sudo apt update
    
    # Instalasi Python virtual environment
    sudo apt install -y python3-venv
    
    log_info "✅ Persiapan sistem selesai."
}

# Cek GPU NVIDIA
check_gpu() {
    log_info "Memeriksa GPU NVIDIA..."
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "Driver NVIDIA tidak terdeteksi. Pastikan NVIDIA driver sudah terpasang!"
        exit 1
    fi
    
    # Tampilkan informasi GPU
    nvidia-smi
}

# Fungsi instalasi Miniconda
install_miniconda() {
    log_info "Mengunduh dan menginstall Miniconda..."
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    
    # Activate dan inisiasi conda
    source ~/miniconda3/bin/activate
    conda init --all
}

# Fungsi instalasi dependensi
install_dependencies() {
    log_info "Menginstall dependensi sistem..."
    sudo apt-get update
    sudo apt-get install -y \
        git \
        python3-pip \
        gcc \
        build-essential \
        screen \
        jq  # Tambahan instalasi jq

    # Upgrade pip
    pip install --upgrade pip
}

# Fungsi clone repository
clone_repository() {
    log_info "Mengunduh repository Heurist Miner..."
    git clone https://github.com/heurist-network/miner-release.git
    cd miner-release
}

# Fungsi setup environment conda
setup_conda_env() {
    log_info "Membuat environment Conda..."
    conda create --name heurist-miner python=3.11 -y
    conda activate heurist-miner
}

# Fungsi instalasi requirements
install_requirements() {
    log_info "Menginstall requirements Python..."
    pip install -r requirements.txt
}

# Fungsi konfigurasi miner
configure_miner() {
    log_info "Membuat file konfigurasi .env dengan alamat: ${EVM_ADDRESS}"
    echo "MINER_ID_0=${EVM_ADDRESS}" > .env
    
    # Tambahan konfigurasi mining
    echo "CUDA_VISIBLE_DEVICES=0" >> .env
    echo "MINING_THREADS=16" >> .env
    
    log_warn "Alamat EVM dan konfigurasi telah dikonfigurasi!"
}

# Fungsi pemeriksaan akhir
final_check() {
    log_info "🔍 Memeriksa konfigurasi akhir..."
    cat .env
    
    # Tampilkan versi Python dan jq
    python --version
    jq --version
}

# Fungsi utama
main() {
    log_info "🚀 Memulai proses instalasi Heurist Miner 🚀"
    
    # Jalankan fungsi-fungsi utama
    prepare_system
    check_gpu
    install_dependencies
    install_miniconda
    clone_repository
    setup_conda_env
    install_requirements
    configure_miner
    final_check
}

# Jalankan fungsi utama
main
