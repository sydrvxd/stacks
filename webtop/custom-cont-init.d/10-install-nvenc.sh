#!/bin/bash
# Install latest NVIDIA NVENC/NVDEC libraries for Blackwell (RTX 50 series) support
# Host driver: 590.48.01 (Blackwell-ready)
# This runs at container startup before the desktop environment starts

set -e

echo "=== NVIDIA NVENC Setup for Blackwell GPU ==="

# Check if NVENC libs are already mounted from host (preferred method)
if [ -f /usr/lib/x86_64-linux-gnu/libnvidia-encode.so.590.48.01 ] || \
   [ -f /usr/lib/x86_64-linux-gnu/libnvidia-encode.so.1 ]; then
    echo "✓ NVENC libraries already present from host driver mount"
    ldconfig -p | grep -i nvidia-encode || true
    echo "=== Skipping installation, using host libraries ==="
    exit 0
fi

echo "Host NVENC libraries not found, installing from NVIDIA repository..."

# Add NVIDIA CUDA repository for latest codec libraries
if [ ! -f /etc/apt/sources.list.d/cuda-ubuntu2204.list ]; then
    echo "Adding NVIDIA CUDA repository..."
    apt-get update -qq
    apt-get install -y -qq wget gnupg2 ca-certificates

    # Add NVIDIA GPG key (new method for Ubuntu 22.04+)
    wget -qO /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i /tmp/cuda-keyring.deb
    rm /tmp/cuda-keyring.deb
    apt-get update -qq
fi

# Install NVENC/NVDEC libraries - try versions matching host driver (590.x)
echo "Installing NVENC/NVDEC libraries..."

# Try to install version closest to host driver first
for version in 590 585 580 575 570 565 560; do
    if apt-cache show libnvidia-encode-${version} >/dev/null 2>&1; then
        echo "Found libnvidia-encode-${version}, installing..."
        apt-get install -y -qq \
            libnvidia-encode-${version} \
            libnvidia-decode-${version} \
            libnvidia-fbc1-${version} 2>/dev/null || true
        break
    fi
    # Also try -server variants
    if apt-cache show libnvidia-encode-${version}-server >/dev/null 2>&1; then
        echo "Found libnvidia-encode-${version}-server, installing..."
        apt-get install -y -qq \
            libnvidia-encode-${version}-server \
            libnvidia-decode-${version}-server 2>/dev/null || true
        break
    fi
done

# Fallback: try generic packages
apt-get install -y -qq libnvidia-encode libnvidia-decode 2>/dev/null || true

# Update library cache
ldconfig

# Verify installation
echo "=== NVENC Installation Summary ==="
if ldconfig -p | grep -q libnvidia-encode; then
    echo "✓ libnvidia-encode found:"
    ldconfig -p | grep libnvidia-encode
else
    echo "✗ libnvidia-encode NOT found"
    echo "  NVENC hardware encoding will not be available"
    echo "  The webtop will fall back to CPU encoding (x264)"
fi

if ldconfig -p | grep -q libnvidia-decode; then
    echo "✓ libnvidia-decode found"
else
    echo "✗ libnvidia-decode NOT found"
fi

# Show GPU info
if command -v nvidia-smi &> /dev/null; then
    echo "=== GPU Info ==="
    nvidia-smi --query-gpu=driver_version,name,memory.total,encoder.stats.sessionCount --format=csv,noheader 2>/dev/null || \
    nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader
fi

echo "=== NVENC setup complete ==="
