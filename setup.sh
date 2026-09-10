bash
#!/usr/bin/env bash

set -e

echo "================================"
echo " Ubuntu Bootstrap"
echo "================================"
echo

# ------------------------------------------------------------
# Helper: install an APT package only if it is not installed
# ------------------------------------------------------------

install_package() {
    local package="$1"

    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "[OK] $package is already installed."
    else
        echo "[INSTALL] Installing $package..."
        sudo apt install -y "$package"
        echo "[OK] $package installed."
    fi
}

# ------------------------------------------------------------
# 1. Check operating system
# ------------------------------------------------------------

echo "[1/10] Checking operating system..."

if [ ! -f /etc/os-release ]; then
    echo "[ERROR] Cannot determine operating system."
    exit 1
fi

. /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    echo "[ERROR] This bootstrap is designed for Ubuntu."
    echo "Detected: $PRETTY_NAME"
    exit 1
fi

echo "[OK] Ubuntu detected: $PRETTY_NAME"

# ------------------------------------------------------------
# 2. Clean broken Ookla repository before apt update
# ------------------------------------------------------------

echo
echo "[2/10] Preparing APT..."

OOKLA_LIST="/etc/apt/sources.list.d/ookla_speedtest-cli.list"

if [ -f "$OOKLA_LIST" ]; then
    echo "[CLEANUP] Removing unsupported Ookla APT repository..."
    sudo rm -f "$OOKLA_LIST"
    echo "[OK] Broken Ookla repository removed."
fi

# Remove any other Ookla source files that may have been created.
sudo find /etc/apt/sources.list.d \
    -type f \
    \( -name '*ookla*' -o -name '*speedtest*' \) \
    -delete 2>/dev/null || true

echo "[UPDATE] Updating package lists..."

sudo apt update

# ------------------------------------------------------------
# 3. Core CLI tools
# ------------------------------------------------------------

echo
echo "[3/10] Checking core CLI tools..."

install_package git
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

# ------------------------------------------------------------
# 4. Networking tools
# ------------------------------------------------------------

echo
echo "[4/10] Checking networking tools..."

install_package nmap

echo
echo "[CHECK] Wireshark..."

if dpkg -s wireshark >/dev/null 2>&1; then
    echo "[OK] wireshark is already installed."
else
    echo "[INSTALL] Installing Wireshark..."

    echo "wireshark-common wireshark-common/install-setuid boolean false" \
        | sudo debconf-set-selections

    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark

    echo "[OK] Wireshark installed."
fi

install_package tcpdump
install_package aircrack-ng
install_package network-manager
install_package dnsutils
install_package traceroute
install_package mtr
install_package ethtool

# ------------------------------------------------------------
# 5. Recovery and storage tools
# ------------------------------------------------------------

echo
echo "[5/10] Checking recovery and storage tools..."

install_package smartmontools
install_package gddrescue
install_package testdisk
install_package parted
install_package gdisk
install_package e2fsprogs

# ------------------------------------------------------------
# 6. Development tools
# ------------------------------------------------------------

echo
echo "[6/10] Checking development tools..."

install_package build-essential
install_package python3
install_package python3-pip
install_package python3-venv
install_package make
install_package pkg-config

# ------------------------------------------------------------
# 7. KDE Connect
# ------------------------------------------------------------

echo
echo "[7/10] Checking KDE Connect..."

install_package kdeconnect

# ------------------------------------------------------------
# 8. Prepare old SSD
# ------------------------------------------------------------

echo
echo "[8/10] Preparing old SSD..."

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

echo
echo "[CHECK] Verifying old SSD mount mode..."

MOUNT_OPTIONS="$(findmnt -no OPTIONS "$OLD_SSD_MOUNT")"

if echo "$MOUNT_OPTIONS" | grep -qw "ro"; then
    echo "[OK] Old SSD is mounted read-only."
else
    echo "[ERROR] Old SSD is NOT mounted read-only."
    echo "Mount options: $MOUNT_OPTIONS"
    exit 1
fi

# ------------------------------------------------------------
# 9. Restore Keyd
# ------------------------------------------------------------

echo
echo "[9/10] Restoring Keyd..."

# Keyd PPA support.
install_package software-properties-common

KEYD_PPA="ppa:keyd-team/ppa"

if grep -Rqs "ppa.launchpadcontent.net/keyd-team/ppa" \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d 2>/dev/null; then

    echo "[OK] Keyd PPA is already configured."

else

    echo "[REPO] Adding Keyd PPA..."

    sudo add-apt-repository -y "$KEYD_PPA"

    echo "[OK] Keyd PPA added."

    echo "[UPDATE] Updating package lists..."

    sudo apt update
fi

# ------------------------------------------------------------
# Install Keyd BEFORE touching its configuration
# ------------------------------------------------------------

install_package keyd

# ------------------------------------------------------------
# Locate the exact configuration we want to migrate
# ------------------------------------------------------------

OLD_KEYD_CONFIG="$OLD_SSD_MOUNT/etc/keyd/default.conf"

CURRENT_KEYD_DIR="/etc/keyd"
CURRENT_KEYD_CONFIG="/etc/keyd/default.conf"

echo
echo "[CHECK] Looking for Keyd configuration..."

if [ ! -f "$OLD_KEYD_CONFIG" ]; then
    echo
    echo "[ERROR] Required Keyd configuration was not found:"
    echo "$OLD_KEYD_CONFIG"
    exit 1
fi

echo "[OK] Found:"
echo "$OLD_KEYD_CONFIG"

# ------------------------------------------------------------
# Back up existing configuration
# ------------------------------------------------------------

sudo mkdir -p "$CURRENT_KEYD_DIR"

if [ -f "$CURRENT_KEYD_CONFIG" ]; then

    echo
    echo "[BACKUP] Existing Keyd configuration found."

    sudo cp -a \
        "$CURRENT_KEYD_CONFIG" \
        "${CURRENT_KEYD_CONFIG}.bootstrap-backup"

    echo "[OK] Existing configuration backed up:"
    echo "${CURRENT_KEYD_CONFIG}.bootstrap-backup"

fi

# ------------------------------------------------------------
# Copy old configuration
# ------------------------------------------------------------

echo
echo "[RESTORE] Copying Keyd default.conf..."

sudo cp -a \
    "$OLD_KEYD_CONFIG" \
    "$CURRENT_KEYD_CONFIG"

echo "[OK] Keyd configuration copied."

# Ensure normal configuration permissions.
sudo chmod 644 "$CURRENT_KEYD_CONFIG"

if [ -f "$CURRENT_KEYD_CONFIG" ]; then
    echo "[OK] Current Keyd configuration exists:"
    echo "$CURRENT_KEYD_CONFIG"
else
    echo "[ERROR] Keyd configuration was not copied."
    exit 1
fi

# ------------------------------------------------------------
# Restart Keyd so the restored configuration is loaded
# ------------------------------------------------------------

echo
echo "[SERVICE] Restarting Keyd..."

sudo systemctl daemon-reload
sudo systemctl enable keyd
sudo systemctl restart keyd

if systemctl is-active --quiet keyd; then

    echo "[OK] Keyd is running."

else

    echo
    echo "[ERROR] Keyd failed to start."
    echo

    echo "Keyd service status:"
    sudo systemctl --no-pager --full status keyd || true

    echo
    echo "Recent Keyd log:"
    sudo journalctl -u keyd -n 30 --no-pager || true

    exit 1

fi

# ------------------------------------------------------------
# 10. Ookla Speedtest
# ------------------------------------------------------------

echo
echo "[10/10] Checking Ookla Speedtest..."

if command -v speedtest >/dev/null 2>&1; then

    echo "[OK] Ookla Speedtest is already installed."

else

    echo "[INSTALL] Installing official Ookla Speedtest..."

    # The Ookla packagecloud repository currently does not provide
    # an Ubuntu Noble repository. Use the official Ubuntu Jammy
    # amd64 package directly instead.
    #
    # The package itself only depends on ca-certificates and installs
    # /usr/bin/speedtest.

    SPEEDTEST_URL="https://packagecloud.io/ookla/speedtest-cli/packages/ubuntu/jammy/speedtest_1.2.0.84-1.ea6b6773cf_amd64.deb/download.deb"

    SPEEDTEST_DEB="/tmp/speedtest_ookla.deb"

    echo "[DOWNLOAD] Downloading Ookla Speedtest package..."

    curl -fL \
        "$SPEEDTEST_URL" \
        -o "$SPEEDTEST_DEB"

    echo "[INSTALL] Installing Ookla Speedtest package..."

    sudo apt install -y "$SPEEDTEST_DEB"

    rm -f "$SPEEDTEST_DEB"

    if command -v speedtest >/dev/null 2>&1; then
        echo "[OK] Ookla Speedtest installed."
    else
        echo "[ERROR] Ookla Speedtest installation failed."
        exit 1
    fi

fi

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo
echo "================================"
echo " Final Verification"
echo "================================"
echo

echo "Git:"
git --version

echo
echo "Curl:"
curl --version | head -1

echo
echo "NetworkManager:"
nmcli --version

echo
echo "Nmap:"
nmap --version | head -1

echo
echo "Wireshark:"
wireshark --version 2>/dev/null | head -1 || true

echo
echo "Tcpdump:"
tcpdump --version 2>/dev/null | head -1 || true

echo
echo "Keyd:"
keyd --version 2>/dev/null || true

echo
echo "Speedtest:"
speedtest --version 2>/dev/null || true

echo
echo "Python:"
python3 --version

echo
echo "Old SSD:"
findmnt "$OLD_SSD_MOUNT"

echo
echo "Old SSD mount options:"
findmnt -no OPTIONS "$OLD_SSD_MOUNT"

echo
echo "Keyd configuration:"
sudo ls -l "$CURRENT_KEYD_CONFIG"

echo
echo "Keyd service:"

if systemctl is-active --quiet keyd; then
    echo "[OK] Keyd is running."
else
    echo "[ERROR] Keyd is not running."
    exit 1
fi

echo
echo "================================"
echo " Bootstrap complete!"
echo "================================"
