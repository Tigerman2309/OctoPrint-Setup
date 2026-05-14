#!/bin/bash
set -e

echo "=== Creating Samba share directories ==="
mkdir -p "$HOME/samba"
mkdir -p "$HOME/backups_share"

echo "=== Setting permissions ==="
chmod 755 "$HOME"
chmod 755 "$HOME/samba"
chmod 755 "$HOME/backups_share"
sudo chown nobody:nogroup "$HOME/samba" "$HOME/backups_share"

echo "=== Creating systemd mount unit ==="
UNIT_FILE="/etc/systemd/system/home-$(whoami)-backups_share.mount"

sudo bash -c "cat <<EOF > $UNIT_FILE
[Unit]
Description=Bind mount for OctoPrint backups
After=local-fs.target
Before=smbd.service

[Mount]
What=%h/.octoprint/data/backup
Where=%h/backups_share
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF"

echo "=== Enabling mount ==="
sudo systemctl daemon-reload
sudo systemctl enable --now "home-$(whoami)-backups_share.mount"

echo "=== Writing Samba configuration ==="
sudo bash -c "cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   map to guest = Bad User
   server min protocol = SMB2
   server max protocol = SMB3
   guest account = nobody

[public]
   path = $HOME/samba
   browseable = yes
   read only = yes
   guest ok = yes
   force user = nobody

[backups]
   path = $HOME/backups_share
   browseable = yes
   read only = yes
   guest ok = yes
   force user = nobody
EOF"

echo "=== Restarting Samba ==="
sudo systemctl restart smbd

echo "=== Setup complete ==="
echo "Public share:  $HOME/samba"
echo "Backups share: $HOME/backups_share"
