#!/bin/bash
set -e

# ============================
# PARAMETERS
# ============================
VENDOR_ID="$1"
PRODUCT_ID="$2"
DEVICE="${3:-/dev/webcam}"
GIT_URL="${4:-https://github.com/jacksonliam/mjpg-streamer.git}"
INSTALL_DIR="${5:-/home/tiger/mjpg-streamer}"

if [ -z "$VENDOR_ID" ] || [ -z "$PRODUCT_ID" ]; then
    echo "Usage: $0 <VendorID> <ProductID> [Device] [GitURL] [InstallDir]"
    exit 1
fi

echo "=== Using parameters ==="
echo "Vendor ID: $VENDOR_ID"
echo "Product ID: $PRODUCT_ID"
echo "Device: $DEVICE"
echo "Git URL: $GIT_URL"
echo "Install Directory: $INSTALL_DIR"

# ============================
# Install dependencies
# ============================
echo "=== Installing dependencies ==="
sudo apt update
sudo apt install -y v4l-utils git build-essential cmake

# ============================
# Clone & build mjpg-streamer
# ============================
echo "=== Cloning mjpg-streamer ==="
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR/mjpg-streamer-experimental" ]; then
    git clone "$GIT_URL" .
fi

echo "=== Building mjpg-streamer ==="
cd mjpg-streamer-experimental
make clean || true
make

# ============================
# Create stable /dev/webcam symlink
# ============================
echo "=== Creating udev rule for /dev/webcam ==="
sudo bash -c "cat <<EOF > /etc/udev/rules.d/99-webcam.rules
SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"$VENDOR_ID\", ATTRS{idProduct}==\"$PRODUCT_ID\", SYMLINK+=\"webcam\"
EOF"

sudo udevadm control --reload-rules
sudo udevadm trigger

# ============================
# Create directories
# ============================
echo "=== Creating directories ==="
mkdir -p /home/tiger/.mjpg-streamer
mkdir -p /home/tiger/scripts
sudo chown -R tiger:tiger /home/tiger/.mjpg-streamer /home/tiger/scripts

# ============================
# Install webcamDaemon
# ============================
echo "=== Installing webcamDaemon ==="
cat <<EOF > /home/tiger/scripts/webcamDaemon
#!/bin/bash

VENDOR_ID="$VENDOR_ID"
PRODUCT_ID="$PRODUCT_ID"
DEVICE="${DEVICE:-/dev/webcam}"

MJPGSTREAMER_HOME="$INSTALL_DIR/mjpg-streamer-experimental"
MJPGSTREAMER_INPUT_USB="input_uvc.so"
LOGFILE="/home/tiger/.mjpg-streamer/webcam.log"

mkdir -p /home/tiger/.mjpg-streamer

echo "Starting webcamDaemon with Vendor=\$VENDOR_ID Product=\$PRODUCT_ID Device=\$DEVICE" | tee -a "\$LOGFILE"

for i in {1..10}; do
    if [ -e "\$DEVICE" ]; then
        echo "Camera detected at \$DEVICE" | tee -a "\$LOGFILE"
        break
    fi
    echo "Waiting for camera (\$i/10)..." | tee -a "\$LOGFILE"
    sleep 1
done

if [ ! -e "\$DEVICE" ]; then
    echo "ERROR: Camera not found at \$DEVICE" | tee -a "\$LOGFILE"
    exit 1
fi

cd "\$MJPGSTREAMER_HOME"

exec ./mjpg_streamer \
    -i "./\${MJPGSTREAMER_INPUT_USB} -d \$DEVICE -r 1280x720 -f 15" \
    -o "./output_http.so -p 8080 -w ./www" \
    >> "\$LOGFILE" 2>&1
EOF

chmod +x /home/tiger/scripts/webcamDaemon

# ============================
# Create systemd service
# ============================
echo "=== Creating systemd service ==="
sudo bash -c "cat <<EOF > /etc/systemd/system/webcam.service
[Unit]
Description=Webcam MJPG-Streamer Service
After=network-online.target

[Service]
User=tiger
ExecStart=/home/tiger/scripts/webcamDaemon
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF"

# ============================
# Enable service
# ============================
echo "=== Enabling webcam service ==="
sudo systemctl daemon-reload
sudo systemctl enable --now webcam

echo "=== Checking stream ==="
sleep 2
sudo ss -tulpn | grep 8080 && echo "Stream running on port 8080"

echo "=== Setup complete ==="
echo "Camera Vendor=$VENDOR_ID Product=$PRODUCT_ID"
echo "mjpg-streamer installed in $INSTALL_DIR"
