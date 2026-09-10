```bash
#!/usr/bin/env bash

set -e

echo "================================"
echo " Ubuntu Bootstrap"
echo "================================"
echo

# --------------------------------------------------
# 1. Update package lists
# --------------------------------------------------

echo "[1/5] Updating package lists..."
sudo apt update

# --------------------------------------------------
# 2. Install Git
# --------------------------------------------------

echo
echo "[2/5] Installing Git..."

sudo apt install -y git

echo "Git installed:"
git --version

# --------------------------------------------------
# 3. Install core CLI tools
# --------------------------------------------------

echo
echo "[3/5] Installing core CLI tools..."

sudo apt install -y \
    curl \
    wget \
    jq \
    tree \
    unzip \
    zip \
    rsync \
    tmux \
    htop \
    btop \
    ncdu \
    ripgrep \
    fd-find \
    file \
    lsof \
    shellcheck \
    nano

# --------------------------------------------------
# 4. Mount old SSD read-only
# --------------------------------------------------

echo
echo "[4/5] Preparing old SSD..."

OLD_SSD="/dev/sda2"
OLD_SSD_MOUNT="/mnt/old-ssd"

sudo mkdir -p "$OLD_SSD_MOUNT"

if mountpoint -q "$OLD_SSD_MOUNT"; then
    echo "Old SSD is already mounted at $OLD_SSD_MOUNT."
else
    echo "Mounting $OLD_SSD read-only..."

    sudo mount -o ro "$OLD_SSD" "$OLD_SSD_MOUNT"

    echo "Old SSD mounted successfully."
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
echo " Bootstrap stage complete!"
echo "================================"
```
