#!/bin/bash
set -e

# ============================================================
# PARAMETERS
# ============================================================
VENDOR_ID="$1"
PRODUCT_ID="$2"

if [ -z "$VENDOR_ID" ] || [ -z "$PRODUCT_ID" ]; then
    echo "Usage: $0 <VendorID> <ProductID>"
    exit 1
fi

DEVICE="/dev/webcam"
GIT_URL="https://github.com/jacksonliam/mjpg-streamer.git"
MJPG_DIR="$HOME/mjpg-streamer"
OCTO_DIR="$HOME/OctoPrint"
HOME_DIR=$(eval echo ~$USER)

echo "=== Starting full headless deployment for user: $(whoami) ==="
echo "Vendor ID: $VENDOR_ID"
echo "Product ID: $PRODUCT_ID"
echo "Home: $HOME"
echo

# ============================================================
# SYSTEM UPDATE
# ============================================================
echo "=== Updating system ==="
sudo apt update
sudo apt upgrade -y

# ============================================================
# INSTALL DEPENDENCIES
# ============================================================
echo "=== Installing dependencies ==="
sudo apt install -y \
    python3 python3-pip python3-venv python3-dev \
    build-essential git libyaml-dev \
    samba v4l-utils cmake libjpeg62-turbo-dev \
    gcc g++

# ============================================================
# OCTOPRINT INSTALLATION
# ============================================================
echo "=== Installing OctoPrint ==="
mkdir -p "$OCTO_DIR"
cd "$OCTO_DIR"

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install octoprint
deactivate

sudo usermod -a -G tty $USER
sudo usermod -a -G dialout $USER

echo "=== Creating OctoPrint systemd template ==="
sudo bash -c "cat <<EOF > /etc/systemd/system/octoprint@.service
[Unit]
Description=OctoPrint instance for $USER
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=$USER
ExecStart=$HOME_DIR/OctoPrint/venv/bin/octoprint serve
Restart=on-failure
Nice=5

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable --now "octoprint@$(whoami)"

# ============================================================
# SAMBA + BACKUPS BIND-MOUNT
# ============================================================
echo "=== Setting up Samba shares ==="

mkdir -p "$HOME/backups_share"

chmod 755 "$HOME" "$HOME/backups_share"
sudo chown nobody:nogroup "$HOME/backups_share"

MOUNT_UNIT="/etc/systemd/system/home-$(whoami)-backups_share.mount"

sudo bash -c "cat <<EOF > $MOUNT_UNIT
[Unit]
Description=Bind mount for OctoPrint backups
After=network-online.target smbd.service
Wants=smbd.service

[Mount]
What=$HOME_DIR/.octoprint/data/backup
Where=$HOME_DIR/backups_share
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF"

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

[backups]
   path = $HOME_DIR/backups_share
   browseable = yes
   read only = yes
   guest ok = yes
   force user = nobody
EOF"

sudo systemctl restart smbd

# ============================================================
# MJPG-STREAMER INSTALLATION
# ============================================================
echo "=== Installing mjpg-streamer ==="

mkdir -p "$MJPG_DIR"
cd "$MJPG_DIR"

if [ ! -d "$MJPG_DIR/mjpg-streamer-experimental" ]; then
    git clone "$GIT_URL" .
fi

cd mjpg-streamer-experimental
make clean || true
make

echo "=== Creating udev rule for /dev/webcam ==="
sudo bash -c "cat <<EOF > /etc/udev/rules.d/99-webcam.rules
SUBSYSTEM==\"video4linux\", KERNEL==\"video[0-9]*\", ATTR{index}==\"0\", ATTRS{idVendor}==\"$VENDOR_ID\", ATTRS{idProduct}==\"$PRODUCT_ID\", SYMLINK+=\"webcam\"
EOF"

sudo udevadm control --reload-rules
sudo udevadm trigger

# ============================================================
# WEBCAM DAEMON
# ============================================================
echo "=== Installing webcamDaemon ==="

mkdir -p "$HOME_DIR/scripts"
mkdir -p "$HOME_DIR/.mjpg-streamer"

cat <<EOF > "$HOME_DIR/scripts/webcamDaemon"
#!/bin/bash

DEVICE="${DEVICE:-/dev/webcam}"
MJPGSTREAMER_HOME="$MJPG_DIR/mjpg-streamer-experimental"
MJPGSTREAMER_INPUT_USB="input_uvc.so"

echo "Starting webcamDaemon using device \$DEVICE"

for i in {1..10}; do
    if [ -e "\$DEVICE" ]; then
        echo "Camera detected at \$DEVICE"
        break
    fi
    echo "Waiting for camera (\$i/10)..."
    sleep 1
done

if [ ! -e "\$DEVICE" ]; then
    echo "ERROR: Camera not found at \$DEVICE"
    exit 1
fi

while true; do
    pushd "\$MJPGSTREAMER_HOME"
    exec ./mjpg_streamer -i "./\${MJPGSTREAMER_INPUT_USB} -d \$DEVICE -r 1280x720 -f 15 -y" -o "./output_http.so -p 8080 -w ./www"
    popd
    sleep 120
done
EOF

chmod +x "$HOME_DIR/scripts/webcamDaemon"

# ============================================================
# SYSTEMD TEMPLATE FOR MJPG-STREAMER
# ============================================================
echo "=== Creating webcam systemd template ==="

sudo bash -c "cat <<EOF > /etc/systemd/system/webcam@.service
[Unit]
Description=Webcam MJPG-Streamer Service for $USER
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$HOME_DIR/scripts/webcamDaemon
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable --now "webcam@$(whoami)"

HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')

# ============================================================
# DONE
# ============================================================
echo
echo "=== Deployment complete ==="
echo "OctoPrint:     http://$IP:5000"
echo "OctoPrint:     http://$HOSTNAME:5000"
echo
echo "Webcam:        http://$IP:8080"
echo "Webcam:        http://$HOSTNAME:8080"
echo
echo "Samba Backups: //$IP/backups"
echo "Samba Backups: //$HOSTNAME/backups"
echo
