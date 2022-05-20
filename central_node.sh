#!/bin/bash

# set -x

### NAMESPACE CREATION
ip netns add net_a
ip netns add net_b
ip netns add net_c

### veth CREATION
ip link add a_eth type veth peer name a_br_eth
ip link add b_eth type veth peer name b_br_eth
ip link add c_eth type veth peer name c_br_eth

### veth <--> namespace ASOCIATION
ip link set a_eth netns net_a
ip link set b_eth netns net_b
ip link set c_eth netns net_c

### ADDRESS ASIGNATION
ip -n net_a addr add 10.0.0.1/24 dev a_eth
ip -n net_b addr add 10.0.0.2/24 dev b_eth
ip -n net_c addr add 10.0.0.3/24 dev c_eth

### loopback & veth UP
ip -n net_a link set lo up
ip -n net_b link set lo up
ip -n net_c link set lo up
ip -n net_a link set dev a_eth up
ip -n net_b link set dev b_eth up
ip -n net_c link set dev c_eth up

### BRIDGE CREATION
ip link add brbr type bridge
ip link set brbr up

### veth <--> bridge CONNECTION
ip link set a_br_eth master brbr
ip link set b_br_eth master brbr
ip link set c_br_eth master brbr

ip link set a_br_eth up
ip link set b_br_eth up
ip link set c_br_eth up

### MAYBE
# ip netns exec net_b sysctl net.ipv4.ip_forward=1

# Wireguard

wg genkey | tee a_privatekey | wg pubkey > a_publickey
wg genkey | tee b_privatekey | wg pubkey > b_publickey
wg genkey | tee c_privatekey | wg pubkey > c_publickey

ip -n net_a link add dev a_wg type wireguard
ip -n net_b link add dev b_wg type wireguard
ip -n net_c link add dev c_wg type wireguard

ip -n net_a addr add 10.0.50.1/24 dev a_wg
ip -n net_b addr add 10.0.50.2/24 dev b_wg
ip -n net_c addr add 10.0.50.3/24 dev c_wg

WG_PORT=51801
ip netns exec net_b wg set b_wg listen-port $WG_PORT private-key b_privatekey
ip netns exec net_b wg set b_wg peer $(<a_publickey) allowed-ips 10.0.50.1/24 endpoint 10.0.0.1:$WG_PORT
ip netns exec net_b wg set b_wg peer $(<c_publickey) allowed-ips 10.0.50.3/24 endpoint 10.0.0.3:$WG_PORT

ip netns exec net_a wg set a_wg listen-port $WG_PORT private-key a_privatekey peer $(<b_publickey) allowed-ips 10.0.50.0/24 endpoint 10.0.0.2:$WG_PORT
ip netns exec net_c wg set c_wg listen-port $WG_PORT private-key c_privatekey peer $(<b_publickey) allowed-ips 10.0.50.0/24 endpoint 10.0.0.2:$WG_PORT

ip -n net_a link set dev a_wg up
ip -n net_b link set dev b_wg up
ip -n net_c link set dev c_wg up

AUX=" &> /dev/null && echo -e '\033[0;32m' bien '\033[0m' || echo -e '\033[0;31m' mal '\033[0m'"

for cmd in \
        "ip a" \
        "ip r" \
        "ping -W 1 -c 1 10.0.0.1 $AUX "\
        "ping -W 1 -c 1 10.0.0.2 $AUX "\
        "ping -W 1 -c 1 10.0.0.3 $AUX "\
        "ping -W 1 -c 1 10.0.50.1 $AUX "\
        "ping -W 1 -c 1 10.0.50.2 $AUX "\
        "ping -W 1 -c 1 10.0.50.3 $AUX "\
        " "
do
    echo A: $cmd
    ip netns exec net_a sh -c "$cmd"
    echo B: $cmd
    ip netns exec net_b sh -c "$cmd"
    echo C: $cmd
    ip netns exec net_c sh -c "$cmd"
done

# Setting down...
ip -n net_a link set dev a_wg down
ip -n net_b link set dev b_wg down
ip -n net_c link set dev c_wg down

ip -n net_a link set dev a_eth down
ip -n net_b link set dev b_eth down
ip -n net_c link set dev c_eth down

ip -n net_a link delete a_eth # also removes a_br_eth
ip -n net_b link delete b_eth # also removes b_br_eth
ip -n net_c link delete c_eth # also removes c_br_eth

ip netns delete net_a
ip netns delete net_b
ip netns delete net_c

ip link set brbr down
brctl delbr brbr
