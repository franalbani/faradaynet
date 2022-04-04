#!/bin/bash

set -x

# Setting up...
ip netns add net_a
ip netns add net_b

ip link add a_eth type veth peer name b_eth

ip link set a_eth netns net_a
ip link set b_eth netns net_b

ip -n net_a link set dev a_eth up
ip -n net_b link set dev b_eth up

ip -n net_a addr add 10.0.0.1/24 dev a_eth
ip -n net_b addr add 10.0.0.2/24 dev b_eth

# Wireguard

wg genkey | tee a_privatekey | wg pubkey > a_publickey
wg genkey | tee b_privatekey | wg pubkey > b_publickey

ip -n net_a link add dev a_wg type wireguard
ip -n net_a addr add 10.0.50.1 dev a_wg peer 10.0.50.2

ip -n net_b link add dev b_wg type wireguard
ip -n net_b addr add 10.0.50.2 dev b_wg peer 10.0.50.1

ip netns exec net_a wg set a_wg listen-port 51801 private-key a_privatekey peer $(<b_publickey) allowed-ips 10.0.50.2 endpoint 10.0.0.2:51802
ip netns exec net_b wg set b_wg listen-port 51802 private-key b_privatekey peer $(<a_publickey) allowed-ips 10.0.50.1 endpoint 10.0.0.1:51801

ip -n net_a link set dev a_wg up
ip -n net_b link set dev b_wg up

ip netns exec net_a ping 10.0.50.2
# ip netns exec net_b ping -c 1 10.0.50.1

# Setting down...
ip -n net_a link set dev a_wg down
ip -n net_b link set dev b_wg down

ip -n net_a link set dev a_eth down
ip -n net_b link set dev b_eth down

ip -n net_a link delete a_eth # also removes b_eth

ip netns delete net_a
ip netns delete net_b
