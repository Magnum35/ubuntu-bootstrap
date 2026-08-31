#!/usr/bin/env bash

set -e

echo "Ubuntu Bootstrap starting..."

echo "[1/3] Updating package lists..."
sudo apt update

echo "[2/3] Installing Git..."
sudo apt install -y git

echo "[3/3] Git installed."

echo
echo "Bootstrap stage complete."
echo "Git version:"
git --version
