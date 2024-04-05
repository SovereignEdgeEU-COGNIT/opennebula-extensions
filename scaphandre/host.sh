#!/usr/bin/env bash

. /etc/os-release

if [ "$ID" = "ubuntu" ]; then

    # Enable Kernel modules
    cpu_info=$(lscpu)
    kernel=$(uname -r)
    kernel_major_version=$(echo "$kernel" | cut -d '.' -f 1)

    if echo "$cpu_info" | grep -qi "Intel"; then
        if [ "$kernel_major_version" -ge 5 ]; then
            # Intel CPU kernel >= 5.0
            modprobe intel_rapl_common
            # Intel CPU kernel <= 5.0
        else
            modprobe intel_rapl
        fi
    elif echo "$cpu_info" | grep -qi "AMD"; then
        kernel_minor_version=$(echo "$kernel" | cut -d '.' -f 2)

        # AMD CPU requires kernel >= 5.11
        if [ "$kernel_major_version" -eq 5 ] && [ "$kernel_minor_version" -ge 11 ] || [ "$kernel_major_version" -gt 5 ]; then
            :
        else
            echo "Kernel > 5.11 required" >&2
            exit 1
        fi
    else
        echo "Failed to determine the CPU manufacturer. Enable rapl kernel modules manually" >&2
    fi

    # Run scaphandre docker container
    apt update && apt install -y docker.io && docker run -d -p 8080:8080 -v /sys/class/powercap:/sys/class/powercap -v /proc:/proc hubblo/scaphandre prometheus --qemu --containers
else
    echo "Linux Distro ${ID} incompatible with scaphandre extension"
    exit 1
fi

one_host_dir=/var/tmp/one/im

if [ -d "$one_host_dir"   ]; then
    state_db=$(ls "$one_host_dir" | grep -oE 'status_kvm_[[:digit:]]+\.db')
    host_id=$(echo "$state_db" | grep -oE '[0-9]+')

config_yaml="- job_name: 'scaphandre'
  static_configs:
    - targets: ['$(hostname):8080']
      labels:
        host_id: $host_id"

    echo "$config_yaml"

else
    echo "Host needs to be added to OpenNebula" >&2
    exit 1
fi


