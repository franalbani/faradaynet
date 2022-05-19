#!/bin/bash

set -x

# Setting up...
ip netns add net_a
ip netns add net_b
ip netns add net_c

ip -n net_a link set lo up
ip -n net_b link set lo up
ip -n net_c link set lo up

ip link add brbr type bridge
ip link set brbr up

ip link add a_eth type veth peer name a_br_eth
ip link add b_eth type veth peer name b_br_eth
ip link add c_eth type veth peer name c_br_eth

ip link set a_br_eth master brbr
ip link set b_br_eth master brbr
ip link set c_br_eth master brbr

ip link set a_br_eth up
ip link set b_br_eth up
ip link set c_br_eth up

ip link set a_eth netns net_a
ip link set b_eth netns net_b
ip link set c_eth netns net_c

ip -n net_a link set dev a_eth up
ip -n net_b link set dev b_eth up
ip -n net_c link set dev c_eth up

ip -n net_a addr add 10.0.0.2/24 dev a_eth
ip -n net_b addr add 10.0.0.1/24 dev b_eth
ip -n net_c addr add 10.0.0.3/24 dev c_eth

# Wireguard

wg genkey | tee a_privatekey | wg pubkey > a_publickey
wg genkey | tee b_privatekey | wg pubkey > b_publickey
wg genkey | tee c_privatekey | wg pubkey > c_publickey

ip -n net_a link add dev a_wg type wireguard
ip -n net_b link add dev b_wg type wireguard
ip -n net_c link add dev c_wg type wireguard

ip -n net_a addr add 10.0.50.2/24 dev a_wg
ip -n net_b addr add 10.0.50.1/24 dev b_wg
ip -n net_c addr add 10.0.50.3/24 dev c_wg

ip netns exec net_a wg set a_wg listen-port 51801 private-key a_privatekey peer $(<b_publickey) allowed-ips 10.0.50.1 endpoint 10.0.0.1:51801
ip netns exec net_c wg set c_wg listen-port 51801 private-key c_privatekey peer $(<b_publickey) allowed-ips 10.0.50.1 endpoint 10.0.0.1:51801

ip netns exec net_b wg set b_wg listen-port 51801 private-key b_privatekey peer $(<a_publickey) allowed-ips 10.0.50.2 endpoint 10.0.0.2:51801 peer $(<c_publickey) allowed-ips 10.0.50.3 endpoint 10.0.0.3:51801

ip -n net_a link set dev a_wg up
ip -n net_b link set dev b_wg up
ip -n net_c link set dev c_wg up

nsenter --net=/var/run/netns/net_a bash
nsenter --net=/var/run/netns/net_a sh -c "ip a; ip r; ping -W 1 -c 1 10.0.0.1; ping -W 1 -c 1 10.0.50.1"
nsenter --net=/var/run/netns/net_c sh -c "ip a; ip r; ping -W 1 -c 1 10.0.0.1; ping -W 1 -c 1 10.0.50.1"

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
