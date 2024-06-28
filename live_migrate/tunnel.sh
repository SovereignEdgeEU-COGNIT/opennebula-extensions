#!/usr/bin/env bash

# TODO: Load from conf of sorts

MTU=1450
TUN_BRIDGE=ovsl2br0
TUN_IFACE=vxlan0
TUNNEL_IPS=(192.168.69.1 192.168.69.2)

get_host_ip() {
    getent hosts $1 | awk '{ print $1 }' | tail -n 1
}

# TODO: Detect if tunnel pre-exists as signal of other migrations happening
# Creates a vlxan tunnel targetting an endpoint
open_tunnel() {
    remote_ip=$1
    tunnel_ip=$2

    sudo ovs-vsctl add-br $TUN_BRIDGE
    sudo ovs-vsctl add-port $TUN_BRIDGE $TUN_IFACE -- set interface $TUN_IFACE type=vxlan options:remote_ip="$remote_ip"

    sudo ip link set dev $TUN_BRIDGE mtu $MTU
    sudo ip address add "$tunnel_ip"/24 dev $TUN_BRIDGE # update openebula sudoers ONE_VNET cmd group

    sudo ip link set up $TUN_BRIDGE
}

close_tunnel() {
    sudo ovs-vsctl del-port $TUN_BRIDGE $TUN_IFACE
    sudo ovs-vsctl del-br $TUN_BRIDGE
}
