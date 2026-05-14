#!/bin/bash
set -e

VENDOR_ID="$1"
PRODUCT_ID="$2"
DEVICE="${3:-/dev/webcam}"
GIT_URL="${4:-https://github.com/jacksonliam/mjpg-streamer.git}"
INSTALL_DIR="${5:-$HOME/mjpg-streamer}"

if [ -z "$VENDOR_ID" ] || [ -z "$PRODUCT_ID" ]; then
    echo "Usage: $0 <VendorID> <ProductID> [Device] [GitURL] [InstallDir]"
    exit 1
fi

echo "=== Installing dependencies ==="
sudo apt update
sudo apt install -y v4l-utils git build-essential cmake

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

echo "=== Creating udev rule ==="
sudo bash -c "cat <<EOF > /etc/udev/rules.d/99-webcam.rules
SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"$VENDOR_ID\", ATTRS{idProduct}==\"$PRODUCT_ID\", SYMLINK+=\"webcam\"
EOF"

sudo udevadm control --reload-rules
sudo udevadm trigger

echo "=== Creating directories ==="
mkdir -p "$HOME/.mjpg-streamer"
mkdir -p "$HOME/scripts"

echo "=== Installing webcamDaemon ==="
cat <<EOF > "$HOME/scripts/webcamDaemon"
#!/bin/bash

VENDOR_ID="$VENDOR_ID"
PRODUCT_ID="$PRODUCT_ID"
DEVICE="${DEVICE:-/dev/webcam}"

MJPGSTREAMER_HOME="$INSTALL_DIR/mjpg-streamer-experimental"
MJPGSTREAMER_INPUT_USB="input_uvc.so"
LOGFILE="\$HOME/.mjpg-streamer/webcam.log"

mkdir -p "\$HOME/.mjpg-streamer"

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

chmod +x "$HOME/scripts/webcamDaemon"

echo "=== Creating systemd template service ==="
sudo bash -c "cat <<EOF > /etc/systemd/system/webcam@.service
[Unit]
Description=Webcam MJPG-Streamer Service for %i
After=network-online.target

[Service]
User=%i
ExecStart=%h/scripts/webcamDaemon
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF"

echo "=== Enabling webcam service ==="
sudo systemctl daemon-reload
sudo systemctl enable --now "webcam@$(whoami)"

echo "=== Checking stream ==="
sleep 2
sudo ss -tulpn | grep 8080 && echo "Stream running on port 8080"

echo "=== Setup complete ==="
