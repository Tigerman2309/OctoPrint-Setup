#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing dependencies ==="
sudo apt install -y python3 python3-pip python3-venv python3-dev \
                     build-essential git libyaml-dev

echo "=== Creating OctoPrint directory ==="
mkdir -p "$HOME/OctoPrint"
cd "$HOME/OctoPrint"

echo "=== Creating Python virtual environment ==="
python3 -m venv venv

echo "=== Installing OctoPrint ==="
source venv/bin/activate
pip install --upgrade pip
pip install octoprint
deactivate

echo "=== Creating systemd service ==="
SERVICE_FILE="/etc/systemd/system/octoprint@.service"

sudo bash -c "cat <<EOF > $SERVICE_FILE
[Unit]
Description=OctoPrint instance for %i
After=network-online.target

[Service]
User=%i
ExecStart=%h/OctoPrint/venv/bin/octoprint serve
Restart=on-failure
Nice=5

[Install]
WantedBy=multi-user.target
EOF"

echo "=== Reloading systemd and enabling OctoPrint ==="
sudo systemctl daemon-reload
sudo systemctl enable --now "octoprint@$(whoami)"

echo "=== Installation complete ==="
echo "OctoPrint is now running at: http://<your-pi-ip>:5000"
