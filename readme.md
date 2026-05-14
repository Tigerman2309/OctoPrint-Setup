## 📘 Headless 3D Printer Deployment Script

### 🚀 Overview

This repository contains a **single, unified, user‑agnostic deployment script** that automatically configures a complete headless 3D‑printer server environment on any Debian‑based system (including Raspberry Pi OS).

The script installs and configures:

**OctoPrint** (Python virtualenv + systemd template)

**mjpg‑streamer** (Git clone + build + udev + systemd template)

**Samba guest shares** (public share + bind‑mounted OctoPrint backups)

**Systemd services** for all components

**Stable `/dev/webcam` symlink** via udev

Everything is fully **user‑agnostic** — no hard‑coded usernames, no assumptions about home directories.
The script adapts automatically to whichever user runs it.
***
### 🧩 Features

#### ✔ User‑agnostic 
Uses `$HOME`, `%h`, and `%i` so it works for any username.

#### ✔ Fully automated
One script configures the entire system end‑to‑end.

#### ✔ OctoPrint installation
- Virtual environment in `$HOME/OctoPrint`
- Systemd template service: `octoprint@<user>`

#### ✔ mjpg‑streamer installation
- Git clone + build from source
- Auto‑generated udev rule for stable `/dev/webcam`
- Systemd template service: `webcam@<user>`

#### ✔ Samba guest shares
- Backups share: `$HOME/backups_share`
- Bind‑mounted from OctoPrint’s backup directory
- No authentication required

#### ✔ Systemd integration
- Auto‑restart
- Clean shutdown
- Template services for multi‑user flexibility
***
### 📦 Requirements
 - Debian 13 / Raspberry Pi OS (Trixie) or newer
 - A USB webcam
 - Internet connection
 - A non‑root user account (script must be run as that user)
 - **Sudo** Access
***
### 🔧 Installation

Clone or download the script, then make it executable:
~~~
chmod +x deploy_headless_printer.sh
~~~
Run it with your camera’s Vendor ID and Product ID:
~~~
./deploy_headless_printer.sh <VendorID> <ProductID>
~~~

#### Example

If `lsusb` shows:

~~~
ID 058f:3841 Alcor Micro Corp. USB HD Camera
~~~
Run:
~~~
./deploy_headless_printer.sh 058f 3841
~~~
***
### 📁 Installed Components

#### 📌 OctoPrint
- Installed in: 
~~~ 
$HOME/OctoPrint 
~~~
- Service: 
~~~
octoprint@<user>
~~~
- URL: 
~~~
http://<ip>:5000
~~~
#### 📌 mjpg-streamer
- Installed in: 
~~~
$HOME/mjpg-streamer/mjpg-streamer-experimental
~~~
- Webcam daemon: 
~~~
$HOME/scripts/webcamDaemon
~~~
- Service: 
~~~
webcam@<user>
~~~
- URL: 
~~~
http://<ip>:8080
~~~
#### 📌 Samba Shares
- Public share (read‑only):
~~~
$HOME/samba
~~~
- OctoPrint backups share (read‑only): 
~~~
$HOME/backups_share
~~~
- Backups are bind‑mounted from: 
~~~
$HOME/.octoprint/data/backup
~~~
***
### 🛠 Systemd Services

#### Enable/disable services manually
~~~
sudo systemctl enable --now octoprint@<user>
sudo systemctl enable --now webcam@<user>
sudo systemctl enable --now home-<user>-backups_share.mount
~~~
#### Check Status
~~~
systemctl status octoprint@$(whoami)
systemctl status webcam@$(whoami)
~~~
***
### 🧪 Troubleshooting

#### Webcam not detected?

Check udev rule:
~~~
ls -l /dev/webcam
~~~
If missing, reload rules:
~~~
sudo udevadm control --reload-rules
sudo udevadm trigger
~~~
#### mjpg‑streamer logs
~~~
$HOME/.mjpg-streamer/webcam.log
~~~
#### OctoPrint logs
~~~
$HOME/.octoprint/logs/
~~~
### 🧹 Uninstall (manual)

✔ Stop services:
~~~
sudo systemctl disable --now octoprint@$(whoami)
sudo systemctl disable --now webcam@$(whoami)
sudo systemctl disable --now home-$(whoami)-backups_share.mount
~~~
✔ Remove directories:
~~~
rm -rf $HOME/OctoPrint
rm -rf $HOME/mjpg-streamer
rm -rf $HOME/scripts
rm -rf $HOME/backups_share
~~~
✔ Remove systemd units:
~~~
sudo rm /etc/systemd/system/octoprint@.service
sudo rm /etc/systemd/system/webcam@.service
sudo rm /etc/systemd/system/home-$(whoami)-backups_share.mount
sudo systemctl daemon-reload
~~~
***
### 📜 License

This script is provided as‑is.
Use, modify, and redistribute freely.
