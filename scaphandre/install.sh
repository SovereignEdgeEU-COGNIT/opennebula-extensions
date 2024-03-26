#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Configure the Host and install Scaphandre as docker container"
  echo "Sudo privileguies are needed."
  echo "Use: $0"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root / sudo privileges." >&2;
  exit 1;
fi

KERNEL_VERSION=$(uname -r)

echo "[INFO] Checking dependencies..."

# Check if docker is installed, install otherwise
if dpkg -l | grep -q "docker-ce"; then
    echo "[INFO] Docker already installed"
else
    echo "[INFO] Installing docker from repositories"

    apt install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    apt-cache policy docker-ce
    apt install docker-ce
fi

# Enable modprobe
echo "[INFO] Kernel version ${KERNEL_VERSION} found"
echo "[INFO] Enabling modprobe"

IFS='.' read -ra version_parts <<< "$kernel_version"

# TODO check if CPU is Intel or AMD first
if [ "${version_parts[0]}" -ge 5 ]; then
  modprobe intel_rapl_common
else
  modprobe intel_rapl
fi

if docker ps | grep "hubblo/scaphandre"; then
  echo "[INFO] Scaphandre container is already running"
else
  echo "[INFO] Starting Scaphandre cointainer"
  docker run -d -p 8080:8080 -v /sys/class/powercap:/sys/class/powercap -v /proc:/proc hubblo/scaphandre prometheus --qemu --containers
fi
