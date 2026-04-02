#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "This script will install rtl-sdr drivers and meshcore tools."
}

# Check if --help or -h is passed
_needs_root=true
for arg in "$@"; do
    if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
        _needs_root=false
        usage
        exit 0
    fi
done

# Ensure running as root (skip for --help so argparse can respond)
if [ "$_needs_root" = true ] && [ "$(id -u)" -ne 0 ]; then
    if [ -f "$0" ]; then
        echo "This installer requires root privileges. Re-running with sudo..."
        exec sudo bash "$0" "$@"
    else
        echo "Error: This installer requires root privileges."
        echo "Please re-run with: curl -fsSL <url> | sudo bash"
        exit 1
    fi
fi

# Check Python 3.11+ requirement
py_version=$(python3 -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}")' 2>/dev/null || true)
if [ -z "$py_version" ] || [ "$(printf '%s\n' "3.11" "$py_version" | sort -V | head -1)" != "3.11" ]; then
    echo "Error: Python 3.11+ required (found: ${py_version:-none})"
    exit 1
fi

# Step 1: Install rtl-sdr dependencies and build
echo "Installing rtl-sdr dependencies..."
sudo apt update
sudo apt install -y git cmake pkg-config libusb-1.0-0-dev sox

echo "Cloning rtl-sdr repository..."
git clone https://gitea.osmocom.org/sdr/rtl-sdr.git
cd rtl-sdr
mkdir build
cd build

echo "Building rtl-sdr..."
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo cp ../rtl-sdr.rules /etc/udev/rules.d/
sudo ldconfig

# Step 2: Blacklist conflicting drivers
echo "Blacklisting conflicting drivers..."
sudo touch /etc/modprobe.d/blacklist-rtl.conf
sudo bash -c 'echo "blacklist dvb_usb_rtl28xxu" > /etc/modprobe.d/blacklist-rtl.conf'
sudo bash -c 'echo "blacklist rtl2832" >> /etc/modprobe.d/blacklist-rtl.conf'
sudo bash -c 'echo "blacklist rtl2830" >> /etc/modprobe.d/blacklist-rtl.conf'

# Step 3: Install pip
echo "Installing pip..."
sudo apt install -y python3-pip

# Step 4: Create virtual environment and install meshcore
echo "Creating virtual environment..."
sudo -H -u "$(logname)" bash <<'EOF'
# ---------- user‑section ----------
echo "User HOME = $HOME"   # should print /home/<user>

cd "$HOME"                # or simply: cd ~
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install meshcore meshcore-cli

deactivate

# Add this line to the end of your ~/.profile or ~/.bashrc
echo 'export PATH="$HOME/venv/bin:$PATH"' >> ~/.profile

# Reload the profile (or log out / log back in)
source ~/.profile
EOF

echo "Installation of RTL-SDR and MeshCore completed successfully!"
echo "Please reboot!"
