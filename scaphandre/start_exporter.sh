#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Start Scaphandre container generating the prometheus job configuration"
  echo "Use: $0 <opennebula_frontend_hostname>"
  exit 1
fi

ONE="$1"
HOSTNAME=$(hostname)

if docker ps | grep "hubblo/scaphandre"; then
  echo "[INFO] Scaphandre container is already running" 
else
  echo "[INFO] Starting Scaphandre cointainer"
  docker run -d -p 8080:8080 -v /sys/class/powercap:/sys/class/powercap -v /proc:/proc hubblo/scaphandre prometheus --qemu --containers
fi

echo "[INFO] Connecting to OpenNebula instance, fetching HOST_ID"

# Connect to the Frontend and get the HOST_ID based on current host hostname
HOST_ID=$(ssh "$ONE" "onehost list -f NAME='$HOSTNAME' --no-header -l id | tr -d '[[:space:]]'")

if [ $? -ne 0 ]; then
  echo "Error connecting via SSH or executing the command on the Frontend.\n"
  echo "Please check that the SSH connection to the OpenNebula Frontend is "
  echo "correctly configured for the user running this script."
  exit 1
fi

echo "[INFO] Generating Prometheus Configuration"
echo "Please add the following endpoint in your Prometheus configuration to enable data collection."
echo "For more information on available metrics and labels, please refer to the README.md attached to this script."
echo "[WARN] In case host_id appears empty, please fill it in manually."
echo "----------------------"

config_yaml="- job_name: 'scaphandre'
  static_configs:
    - targets: ['$HOSTNAME:8080']
      labels:
        host_id: $HOST_ID"

echo "$config_yaml"