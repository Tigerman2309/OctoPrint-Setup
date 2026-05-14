#!/bin/bash
set -e

echo "=== Creating Samba share directories ==="
mkdir -p /home/tiger/samba
mkdir -p /home/tiger/backups_share

echo "=== Setting permissions ==="
chmod 755 /home/tiger
chmod 755 /home/tiger/samba
chmod 755 /home/tiger/backups_share
chown nobody:nogroup /home/tiger/samba
chown nobody:nogroup /home/tiger/backups_share

echo "=== Creating systemd mount unit for OctoPrint backups ==="
UNIT_FILE="/etc/systemd/system/home-tiger-backups_share.mount"

sudo bash -c "cat <<EOF > $UNIT_FILE
[Unit]
Description=Bind mount for OctoPrint backups
After=local-fs.target
Before=smbd.service nmbd.service

[Mount]
What=/home/tiger/.octoprint/data/backup
Where=/home/tiger/backups_share
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF"

echo "=== Reloading systemd and enabling mount ==="
sudo systemctl daemon-reload
sudo systemctl enable --now home-tiger-backups_share.mount

echo '=== Writing Samba configuration ==='
SMB_CONF="/etc/samba/smb.conf"

sudo bash -c "cat <<EOF > $SMB_CONF
[global]
   workgroup = WORKGROUP
   map to guest = Bad User
   server min protocol = SMB2
   server max protocol = SMB3
   guest account = nobody

[public]
   path = /home/tiger/samba
   browseable = yes
   read only = yes
   guest ok = yes
   force user = nobody

[backups]
   path = /home/tiger/backups_share
   browseable = yes
   read only = yes
   guest ok = yes
   force user = nobody
EOF"

echo "=== Restarting Samba ==="
sudo systemctl restart smbd nmbd

echo "=== Verifying mount ==="
mount | grep backups_share || echo "WARNING: backups_share is not mounted!"

echo "=== Setup complete ==="
echo "Public share:  /home/tiger/samba"
echo "Backups share: /home/tiger/backups_share (bind-mounted from OctoPrint)"
