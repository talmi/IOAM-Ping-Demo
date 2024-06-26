# IOAM-Ping-Demo

## Overview
This demo presents a simple utility that sends a Ping request using ICMPv6 Loopback messages between two network namespaces: Alpha sends a request to Beta and receives a reply. The request includes IOAM data (RFC 9197) that is encapsulated in an IPv6 option (RFC 9486). The demo presents, beyond the conventional Ping information, also the IOAM data that was collected.

The messages exchanged between Alpha and Beta are ICMPv6 Loopback request and reply messages, based on the following Internet draft:

https://datatracker.ietf.org/doc/draft-mcb-6man-icmpv6-loopback/

The following diagram illustrates the two nodes. Alpha is the IOAM encapsulating node and Beta is the IOAM decapsulating node. Alpha sends ICMPv6 Loopback requests to Beta, and each request incorporates the IOAM Pre-allocated Trace Option. IOAM data is incorporated into the Trace Option by both Alpha and Beta. When Beta receives an ICMPv6 Loopback request it generates an ICMPv6 Loopback reply, in which the payload incorporates the ICMPv6 Loopback request including its IPv6 header, IPv6 options (with the IOAM data) and the payload. When the Loopback reply reaches Alpha it is parsed and the IOAM data that was collected in the Loopback request is printed and presented to the user.
```
           +---------------------+           +---------------------+
           |                     |           |                     |
           |     Alpha netns     |           |     Beta netns      |
           |                     |           |                     |
           |   +-------------+   |           |   +-------------+   |
           |   |    veth0    |   |           |   |    veth0    |   |
           |   |  db01::2/64 | . | . . . . . | . |  db01::1/64 |   |
           |   +-------------+   |           |   +-------------+   |
           |                     |           |                     |
           +---------------------+           +---------------------+
```


This demo is just a proof of concept for experimentation purposes and should not be run in a real network.

## Prerequisites
The demo was tested on Ubuntu 22.04.4. Since it requires patching the kernel, it is recommended to run the demo on a dedicated machine or VM that is not used for other purposes. It is preferable to use a fresh installation of Ubuntu or a Debian variant.

## Patching the Linux Kernel
The first step is to download the Linux kernel code. This demo was tested with version 6.8, downloaded from kernel.org:

https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz

Extract the file above, and download the patch file from the current repository to the kernel folder:

https://github.com/talmi/IOAM-Ping-Demo/blob/main/icmpv6-loopback.patch

Apply the patch:
```
git apply icmpv6-loopback.patch 
```

Proceed with making* and installing the kernel, e.g., by following the instructions on:
https://phoenixnap.com/kb/build-linux-kernel

*Note: "CONFIG_IPV6_IOAM6_LWTUNNEL" must be enabled before compiling (e.g., with "make menuconfig") in order to be able to add the Pre-allocated Trace Option-Type to packets.

## Patching iputils

Get the iputils code:

https://github.com/iputils/iputils

Download the iputils patch file for this demo from this repository: 

https://github.com/talmi/IOAM-Ping-Demo/blob/main/IOAM-Ping-Demo-iputils.patch

Apply the patch:

```
git apply IOAM-Ping-Demo-iputils.patch
```

Make and install iputils according to the README.md file in the iputils repository.

## Installing iproute2
In order to make sure that IOAM is supported, install iproute2. The iproute2 version should match the kernel version you installed. For example:

https://mirrors.edge.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.8.0.tar.xz

Follow the instructions on the README file in the iproute2 folder to make and install.

## Running IOAM-Ping
Run the script:

```
sudo ./ioam-ping.sh
```

The script sends 5 ICMPv6 Loopback messages with IOAM and prints the result. It also captures a pcap file.
If everything runs smoothly, you should see something like:

```
PING db01::1 (db01::1) 56 data bytes
152 bytes from db01::1: icmp_seq=1 ttl=64 time=0.192 ms IOAM: NodeID=1,HopLim=64,RcvTime=NA NodeID=2,HopLim=63,RcvTime=1712811441.126
152 bytes from db01::1: icmp_seq=2 ttl=64 time=0.078 ms IOAM: NodeID=1,HopLim=64,RcvTime=NA NodeID=2,HopLim=63,RcvTime=1712811442.129
```

This demo was put together by Ben Ben Ishay, Amit Geron, Justin Iurman and Tal Mizrahi.
