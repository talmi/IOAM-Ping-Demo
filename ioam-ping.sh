#!/bin/bash

#           +---------------------+           +---------------------+
#           |                     |           |                     |
#           |     Alpha netns     |           |     Beta netns      |
#           |                     |           |                     |
#           |   +-------------+   |           |   +-------------+   |
#           |   |    veth0    |   |           |   |    veth0    |   |
#           |   |  db01::2/64 | . | . . . . . | . |  db01::1/64 |   |
#           |   +-------------+   |           |   +-------------+   |
#           |                     |           |                     |
#           +---------------------+           +---------------------+
#
#
#        =============================================================
#        |                Alpha - IOAM configuration                 |
#        +===========================================================+
#        | Node ID             | 1                                   |
#        +-----------------------------------------------------------+
#        | Node Wide ID        | 11111111                            |
#        +-----------------------------------------------------------+
#        | Ingress ID          | 0xffff (default value)              |
#        +-----------------------------------------------------------+
#        | Ingress Wide ID     | 0xffffffff (default value)          |
#        +-----------------------------------------------------------+
#        | Egress ID           | 101                                 |
#        +-----------------------------------------------------------+
#        | Egress Wide ID      | 101101                              |
#        +-----------------------------------------------------------+
#        | Namespace Data      | 0xdeadbee0                          |
#        +-----------------------------------------------------------+
#        | Namespace Wide Data | 0xcafec0caf00dc0de                  |
#        +-----------------------------------------------------------+
#        | Schema ID           | 777                                 |
#        +-----------------------------------------------------------+
#        | Schema Data         | something that will be 4n-aligned   |
#        +-----------------------------------------------------------+
#
#
#        =============================================================
#        |                 Beta - IOAM configuration                 |
#        +===========================================================+
#        | Node ID             | 2                                   |
#        +-----------------------------------------------------------+
#        | Node Wide ID        | 22222222                            |
#        +-----------------------------------------------------------+
#        | Ingress ID          | 201                                 |
#        +-----------------------------------------------------------+
#        | Ingress Wide ID     | 201201                              |
#        +-----------------------------------------------------------+
#        | Egress ID           | 0xffff (default value)              |
#        +-----------------------------------------------------------+
#        | Egress Wide ID      | 0xffffffff (default value)          |
#        +-----------------------------------------------------------+
#        | Namespace Data      | 0xdeadbee1                          |
#        +-----------------------------------------------------------+
#        | Namespace Wide Data | 0xcafec0caf11dc0de                  |
#        +-----------------------------------------------------------+
#        | Schema ID           | 666                                 |
#        +-----------------------------------------------------------+
#        | Schema Data         | Hello there -Obi                    |
#        +-----------------------------------------------------------+

ALPHA=(
	1					# ID
	11111111				# Wide ID
	0xffff					# Ingress ID
	0xffffffff				# Ingress Wide ID
	101					# Egress ID
	101101					# Egress Wide ID
	0xdeadbee0				# Namespace Data
	0xcafec0caf00dc0de			# Namespace Wide Data
	777					# Schema ID (0xffffff = None)
	"something that will be 4n-aligned"	# Schema Data
)

BETA=(
	2
	22222222
	201
	201201
	0xffff
	0xffffffff
	0xdeadbee1
	0xcafec0caf11dc0de
	666
	"Hello there -Obi"
)


check_kernel_compatibility()
{
  ip netns add ioam_tmp_node

  ip link add name ioam-veth0 netns ioam_tmp_node type veth \
         peer name ioam-veth1 netns ioam_tmp_node

  ip -netns ioam_tmp_node link set ioam-veth0 up
  ip -netns ioam_tmp_node link set ioam-veth1 up

  ip -netns ioam_tmp_node ioam namespace add 0
  ns_ad=$?

  ip -netns ioam_tmp_node ioam namespace show | grep -q "namespace 0"
  ns_sh=$?

  if [[ $ns_ad != 0 || $ns_sh != 0 ]]
  then
    echo "SKIP: kernel version probably too old, missing ioam support"
    ip link del ioam-veth0 2>/dev/null || true
    ip netns del ioam_tmp_node || true
    exit 1
  fi

  ip -netns ioam_tmp_node route add db02::/64 encap ioam6 mode inline \
         trace prealloc type 0x800000 ns 0 size 4 dev ioam-veth0
  tr_ad=$?

  ip -netns ioam_tmp_node -6 route | grep -q "encap ioam6"
  tr_sh=$?

  if [[ $tr_ad != 0 || $tr_sh != 0 ]]
  then
    echo "SKIP: cannot attach an ioam trace to a route, did you compile" \
         "the kernel without enabling CONFIG_IPV6_IOAM6_LWTUNNEL?"
    ip link del ioam-veth0 2>/dev/null || true
    ip netns del ioam_tmp_node || true
    exit 1
  fi

  ip link del ioam-veth0 2>/dev/null || true
  ip netns del ioam_tmp_node || true

  lsmod | grep -q "ip6_tunnel"
  ip6tnl_loaded=$?

  if [ $ip6tnl_loaded = 0 ]
  then
    encap_tests=0
  else
    modprobe ip6_tunnel &>/dev/null
    lsmod | grep -q "ip6_tunnel"
    encap_tests=$?

    if [ $encap_tests != 0 ]
    then
      ip a | grep -q "ip6tnl0"
      encap_tests=$?

      if [ $encap_tests != 0 ]
      then
        echo "Note: ip6_tunnel not found neither as a module nor inside the" \
             "kernel. The only IOAM encap mode available is the \"inline\" one."
      fi
    fi
  fi
}

cleanup()
{
  ip link del ioam-veth-alpha 2>/dev/null || true

  ip netns del ioam_node_alpha || true
  ip netns del ioam_node_beta || true

  if [ $ip6tnl_loaded != 0 ]
  then
    modprobe -r ip6_tunnel 2>/dev/null || true
  fi
}

setup()
{
  ip netns add ioam_node_alpha
  ip netns add ioam_node_beta

  ip link add name ioam-veth-alpha netns ioam_node_alpha type veth \
         peer name ioam-veth-beta netns ioam_node_beta

  ip -netns ioam_node_alpha link set ioam-veth-alpha name veth0
  ip -netns ioam_node_beta link set ioam-veth-beta name veth0

  ip -netns ioam_node_alpha addr add db01::2/64 dev veth0
  ip -netns ioam_node_alpha link set veth0 up
  ip -netns ioam_node_alpha link set lo up

  ip -netns ioam_node_beta addr add db01::1/64 dev veth0
  ip -netns ioam_node_beta link set veth0 up
  ip -netns ioam_node_beta link set lo up

  # - IOAM config -
  ip netns exec ioam_node_alpha sysctl -wq net.ipv6.ioam6_id=${ALPHA[0]}
  ip netns exec ioam_node_alpha sysctl -wq net.ipv6.ioam6_id_wide=${ALPHA[1]}
  ip netns exec ioam_node_alpha sysctl -wq net.ipv6.conf.veth0.ioam6_id=${ALPHA[4]}
  ip netns exec ioam_node_alpha sysctl -wq net.ipv6.conf.veth0.ioam6_id_wide=${ALPHA[5]}
  ip -netns ioam_node_alpha ioam namespace add 123 data ${ALPHA[6]} wide ${ALPHA[7]}
  ip -netns ioam_node_alpha ioam schema add ${ALPHA[8]} "${ALPHA[9]}"
  ip -netns ioam_node_alpha ioam namespace set 123 schema ${ALPHA[8]}

  ip netns exec ioam_node_beta sysctl -wq net.ipv6.ioam6_id=${BETA[0]}
  ip netns exec ioam_node_beta sysctl -wq net.ipv6.ioam6_id_wide=${BETA[1]}
  ip netns exec ioam_node_beta sysctl -wq net.ipv6.conf.veth0.ioam6_enabled=1
  ip netns exec ioam_node_beta sysctl -wq net.ipv6.conf.veth0.ioam6_id=${BETA[2]}
  ip netns exec ioam_node_beta sysctl -wq net.ipv6.conf.veth0.ioam6_id_wide=${BETA[3]}
  ip -netns ioam_node_beta ioam namespace add 123 data ${BETA[6]} wide ${BETA[7]}
  ip -netns ioam_node_beta ioam schema add ${BETA[8]} "${BETA[9]}"
  ip -netns ioam_node_beta ioam namespace set 123 schema ${BETA[8]}

  sleep 1

  ip netns exec ioam_node_alpha ping -6 -c 5 -W 1 db01::1 &>/dev/null
  if [ $? != 0 ]
  then
    echo "Setup FAILED"
    cleanup &>/dev/null
    exit 1
  fi

  ip -netns ioam_node_alpha route del db01::/64
  #TODO if you want to modify the IOAM trace-type below...
  # ... or the pre-allocated size...
  ip -netns ioam_node_alpha route add db01::/64 encap ioam6 mode inline \
         trace prealloc type 0xB00000 ns 123 size 24 dev veth0
         #trace prealloc type 0xfff002 ns 123 size 244 dev veth0
}

if [ "$(id -u)" -ne 0 ]
then
  echo "SKIP: Need root privileges"
  exit 1
fi

if [ ! -x "$(command -v ip)" ]
then
  echo "SKIP: Could not run test without ip tool"
  exit 1
fi

ip ioam &>/dev/null
if [ $? = 1 ]
then
  echo "SKIP: iproute2 too old, missing ioam command"
  exit 1
fi

check_kernel_compatibility

cleanup &>/dev/null
setup

ip netns exec ioam_node_alpha tcpdump -i veth0 'ip6' -w alpha.pcap &
tcpdump_pid=$!
sleep 0.5

#TODO replace by your ping utility
ip netns exec ioam_node_alpha ping -6 -k -K -c 5 -W 1 db01::1

sleep 1
kill -2 $tcpdump_pid &>/dev/null

cleanup &>/dev/null

