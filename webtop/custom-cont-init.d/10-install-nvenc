#!/bin/bash
# Install latest NVIDIA NVENC/NVDEC libraries for Blackwell (RTX 50 series) support
# Host driver: 590.48.01 (Blackwell-ready)

echo "=== NVIDIA NVENC Setup for Blackwell GPU ==="

# Check if NVENC libs are already present
if ldconfig -p 2>/dev/null | grep -q libnvidia-encode; then
    echo "NVENC libraries already present:"
    ldconfig -p | grep -i nvidia-encode
    echo "=== Using existing libraries ==="
    exit 0
fi

echo "Installing NVENC libraries from NVIDIA repository..."

# Add NVIDIA CUDA repository
apt-get update -qq
apt-get install -y -qq wget gnupg2 ca-certificates

wget -qO /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i /tmp/cuda-keyring.deb
rm /tmp/cuda-keyring.deb
apt-get update -qq

# Install NVENC/NVDEC libraries
for version in 590 585 580 575 570 565 560; do
    if apt-cache show libnvidia-encode-${version} >/dev/null 2>&1; then
        echo "Installing libnvidia-encode-${version}..."
        apt-get install -y -qq libnvidia-encode-${version} libnvidia-decode-${version} || true
        break
    fi
    if apt-cache show libnvidia-encode-${version}-server >/dev/null 2>&1; then
        echo "Installing libnvidia-encode-${version}-server..."
        apt-get install -y -qq libnvidia-encode-${version}-server libnvidia-decode-${version}-server || true
        break
    fi
done

ldconfig

echo "=== NVENC Installation Summary ==="
ldconfig -p | grep -i nvidia-encode || echo "WARNING: libnvidia-encode NOT found"
nvidia-smi --query-gpu=driver_version,name --format=csv,noheader 2>/dev/null || true
echo "=== Done ==="
