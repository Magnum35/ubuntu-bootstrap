bash
#!/usr/bin/env bash

set -e

echo "================================"
echo " Ubuntu Bootstrap"
echo "================================"
echo

# --------------------------------------------------
# Function: install a package if it is not installed
# --------------------------------------------------

install_package() {
    local package="$1"

    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "[OK] $package is already installed."
    else
        echo "[INSTALL] Installing $package..."
        sudo apt install -y "$package"
    fi
}

# --------------------------------------------------
# 1. Update package lists
# --------------------------------------------------

echo "[1/5] Updating package lists..."

sudo apt update

# --------------------------------------------------
# 2. Install Git
# --------------------------------------------------

echo
echo "[2/5] Checking Git..."

install_package git

echo
echo "Git version:"
git --version

# --------------------------------------------------
# 3. Install core CLI tools
# --------------------------------------------------

echo
echo "[3/5] Checking core CLI tools..."

install_package curl
install_package wget
install_package jq
install_package tree
install_package unzip
install_package zip
install_package rsync
install_package tmux
install_package htop
install_package btop
install_package ncdu
install_package ripgrep
install_package fd-find
install_package file
install_package lsof
install_package shellcheck
install_package nano

# --------------------------------------------------
# 4. Mount old SSD read-only
# --------------------------------------------------

echo
echo "[4/5] Preparing old SSD..."

OLD_SSD="/dev/sda2"
OLD_SSD_MOUNT="/mnt/old-ssd"

sudo mkdir -p "$OLD_SSD_MOUNT"

if mountpoint -q "$OLD_SSD_MOUNT"; then
    echo "[OK] Old SSD is already mounted at $OLD_SSD_MOUNT."
else
    echo "[MOUNT] Mounting $OLD_SSD read-only..."

    sudo mount -o ro "$OLD_SSD" "$OLD_SSD_MOUNT"

    echo "[OK] Old SSD mounted successfully."
fi

# --------------------------------------------------
# 5. Verify
# --------------------------------------------------

echo
echo "[5/5] Verifying setup..."

echo
echo "Git:"
git --version

echo
echo "Old SSD:"
findmnt "$OLD_SSD_MOUNT"

echo
echo "Old SSD contents:"
sudo ls "$OLD_SSD_MOUNT"

echo
echo "================================"
echo "Bootstrap stage complete!"
echo "================================"
```
