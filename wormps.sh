#!/bin/bash

# usage: sudo -E ./wormps.sh command arg1 arg2 ...

WG_DEV="vpnserver"
WORM_NS="worm_ns"

function cleanup {
    # Bring Wireguard down:
    ip -n $WORM_NS link set $WG_DEV down || true
    ip -n $WORM_NS link delete $WG_DEV || true
    # Remove network namespace:
    ip netns delete $WORM_NS || true
}
trap cleanup EXIT

set -x

VPN_SERVER_PUBLIC_KEY="BSXSJgI+cpLA2TrGL2swcqaXuCSjNNw9PVK7E0yCqFo="
VPN_SERVER_ENDPOINT="66.90.72.170:51820"
MY_IP="10.2.0.2/32" # put your the ip your vpn provider assigned you here
MY_PRIVATE_KEY_PATH="my_privatekey" # put the path to a file containing your private key here

# First create Wireguard interface in initial/root namespace
# so the UDP socket is created here and can access internet
# after being moved to another network namespace:
ip link add dev $WG_DEV type wireguard

# Create namespace
ip netns add $WORM_NS

# Move wg dev to netns
ip link set $WG_DEV netns $WORM_NS

# Configure Wireguard interface:
ip -n $WORM_NS addr add $MY_IP dev $WG_DEV
ip netns exec $WORM_NS wg set $WG_DEV listen-port 51801 \
                                      private-key $MY_PRIVATE_KEY_PATH \
                                      peer $VPN_SERVER_PUBLIC_KEY \
                                      allowed-ips 0.0.0.0/0 \
                                      endpoint $VPN_SERVER_ENDPOINT

# Make route all traffic through Wireguard interface:
ip -n $WORM_NS link set lo up
ip -n $WORM_NS link set $WG_DEV up
ip -n $WORM_NS route add default dev $WG_DEV

# This executes your commmand + args (represented by $@)
# as your original user (not root) inside the $WORM_NS:

ip netns exec $WORM_NS sudo -u $SUDO_USER -g $SUDO_USER "$@"

