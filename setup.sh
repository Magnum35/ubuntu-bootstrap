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
# Function: check if a command exists
# --------------------------------------------------

check_command() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        echo "[OK] Command '$command_name' is available."
    else
        echo "[ERROR] Command '$command_name' is not available."
        return 1
    fi
}

# --------------------------------------------------
# 1. Check Ubuntu
# --------------------------------------------------

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

# --------------------------------------------------
# 2. Update package lists
# --------------------------------------------------

echo
echo "[2/10] Updating package lists..."

sudo apt update

# --------------------------------------------------
# 3. Core CLI tools
# --------------------------------------------------

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

# --------------------------------------------------
# 4. Networking tools
# --------------------------------------------------

echo
echo "[4/10] Checking networking tools..."

install_package nmap

# --------------------------------------------------
# Wireshark
# Force safest option:
# non-superusers are NOT allowed to capture packets
# --------------------------------------------------

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

# --------------------------------------------------
# 5. Recovery and storage tools
# --------------------------------------------------

echo
echo "[5/10] Checking recovery and storage tools..."

install_package smartmontools
install_package gddrescue
install_package testdisk
install_package parted
install_package gdisk
install_package e2fsprogs

# --------------------------------------------------
# 6. Development tools
# --------------------------------------------------

echo
echo "[6/10] Checking development tools..."

install_package build-essential
install_package python3
install_package python3-pip
install_package python3-venv
install_package make
install_package pkg-config

# --------------------------------------------------
# 7. KDE Connect
# --------------------------------------------------

echo
echo "[7/10] Checking KDE Connect..."

install_package kdeconnect

# --------------------------------------------------
# 8. Mount old SSD read-only
# --------------------------------------------------

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

# --------------------------------------------------
# Verify old SSD is actually read-only
# --------------------------------------------------

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

# --------------------------------------------------
# 9. Restore Keyd
# --------------------------------------------------

echo
echo "[9/10] Restoring Keyd..."

# add-apt-repository is provided by software-properties-common
install_package software-properties-common

KEYD_PPA="ppa:keyd-team/ppa"

# --------------------------------------------------
# Check whether Keyd PPA already exists
# --------------------------------------------------

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

# --------------------------------------------------
# Install Keyd
# --------------------------------------------------

install_package keyd

# --------------------------------------------------
# Check old Keyd configuration
# --------------------------------------------------

OLD_KEYD_CONFIG="$OLD_SSD_MOUNT/etc/keyd"
CURRENT_KEYD_CONFIG="/etc/keyd"

if [ ! -d "$OLD_KEYD_CONFIG" ]; then

    echo
    echo "[ERROR] Old Keyd configuration was not found:"
    echo "$OLD_KEYD_CONFIG"

    exit 1

fi

echo
echo "[OK] Old Keyd configuration found."

# --------------------------------------------------
# Restore Keyd configuration
# --------------------------------------------------

echo
echo "[RESTORE] Restoring Keyd configuration..."

sudo mkdir -p "$CURRENT_KEYD_CONFIG"

sudo cp -a "$OLD_KEYD_CONFIG/." "$CURRENT_KEYD_CONFIG/"

echo "[OK] Keyd configuration restored."

# --------------------------------------------------
# Enable and start Keyd
# --------------------------------------------------

echo
echo "[SERVICE] Checking Keyd service..."

if systemctl is-active --quiet keyd; then

    echo "[OK] Keyd service is already running."

else

    echo "[START] Starting Keyd..."

    sudo systemctl enable --now keyd

    echo "[OK] Keyd service started."

fi

# --------------------------------------------------
# Verify Keyd
# --------------------------------------------------

if systemctl is-active --quiet keyd; then

    echo "[OK] Keyd is running."

else

    echo "[ERROR] Keyd failed to start."

    exit 1

fi

# --------------------------------------------------
# 10. Ookla Speedtest CLI
# --------------------------------------------------

echo
echo "[10/10] Checking Ookla Speedtest..."

if dpkg -s speedtest >/dev/null 2>&1; then

    echo "[OK] Ookla Speedtest is already installed."

else

    echo "[INSTALL] Setting up Ookla Speedtest repository..."

    install_package gnupg

    if grep -Rqs "packagecloud.io/ookla/speedtest-cli" \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d 2>/dev/null; then

        echo "[OK] Ookla Speedtest repository is already configured."

    else

        echo "[REPO] Adding Ookla Speedtest repository..."

        curl -fsSL \
            "https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh" \
            | sudo bash

        echo "[OK] Ookla Speedtest repository added."

        echo "[UPDATE] Updating package lists..."

        sudo apt update

    fi

    echo "[INSTALL] Installing Ookla Speedtest..."

    sudo apt install -y speedtest

    echo "[OK] Ookla Speedtest installed."

fi

# --------------------------------------------------
# Final verification
# --------------------------------------------------

echo
echo "================================"
echo " Final Verification"
echo "================================"
echo

echo "Git:"
git --version

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
echo "Old SSD contents:"
sudo ls "$OLD_SSD_MOUNT"

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
