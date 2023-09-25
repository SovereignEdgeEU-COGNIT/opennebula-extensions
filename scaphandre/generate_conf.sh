#!/bin/bash
if [ $# -ne 1 ]; then
  echo "Generates Prometheus configuration for Scaphandre container"
  echo "Use: $0"
  exit 1
fi

ONE="$1"
HOSTNAME=$(hostname)

# Get the HOST_ID from monitor DB name
echo "[INFO] Getting HOST_ID"

DB_NAME=$(ls im/ | grep -oE 'status_kvm_[[:digit:]]+\.db')
HOST_ID=$(echo "$DB_NAME" | grep -oE '[0-9]+')

if [ -z "$HOST_ID" ]; then
  echo "Error obtaining the host id from the monitoring database."
  echo "Please check if /var/tmp/one/im/status_kvm_X.db file exists "
  echo "and if this Host is currently monitored by OpenNebula."
  exit 1
fi

echo "[INFO] Generating Prometheus Configuration"
echo "Please add the following endpoint in your Prometheus configuration to enable data collection."
echo "For more information on available metrics and labels, please refer to the README.md attached to this script."
echo "----------------------"

config_yaml="- job_name: 'scaphandre'
  static_configs:
    - targets: ['$HOSTNAME:8080']
      labels:
        host_id: $HOST_ID"

echo "$config_yaml"
