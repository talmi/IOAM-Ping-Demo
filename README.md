# IOAM-Ping-Demo

## Overview
This demo presents a simple utility that sends a Ping request using ICMP Loopback messages between two network namespaces: Alpha sends a request to Beta and receives a reply. The request includes IOAM data (RFC 9197) that is encapsulated in an IPv6 option (RFC 9486). The demo presents, beyond the conventional Ping information, also the IOAM data that was collected.

The messages exchanged between Alpha and Beta are ICMP Loopback request and reply messages, based on the following Internet draft:

https://datatracker.ietf.org/doc/draft-mcb-6man-icmpv6-loopback/

This demo is just a proof of concept for experimentation purposes and should not be run in a real network.

## Prerequisites
The demo was tested on Ubuntu 22.04.4. Since it requires patching the kernel, it is recommended to run the demo on a dedicated machine or VM that is not used for other purposes. It is preferable to use a fresh installation of Ubuntu or a Debian variant.

## Patching the Linux Kernel
The first step is to download the Linux kernel code. This demo was tested with version 6.8, downloaded from kernel.org:

https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz

Extract the file above, and download the following patch files to the kernel folder:

https://github.com/BenBenIshay/TRC-Telemetry-kernel/commit/4a06c1378c268e1a7047f0ad3a380eecd1b5e228.patch

https://github.com/BenBenIshay/TRC-Telemetry-kernel/commit/05e623c38521a5f5e7ab9dc753683c7f806ba7ad.patch

https://github.com/BenBenIshay/TRC-Telemetry-kernel/commit/baf2fe9455a1e3bef5270b97c16f776d200d816b.patch

Apply the patch - perform the following for each of the three files:
```
git apply <file name>
```

Proceed with making and installing the kernel, e.g., by following the instructions on:
https://phoenixnap.com/kb/build-linux-kernel
 

## Patching iputils

Get the latest iputils code:

https://github.com/iputils/iputils

Download the iputils patch file for this demo from this repository: 

https://github.com/talmi/IOAM-Ping-Demo/blob/main/IOAM-Ping-Demo-iputils.patch

Apply the patch:

```
git apply IOAM-Ping-Demo-iputils.patch
```

Make and install iputils according to the README.md file in the iputils repository.

## Installing iproute2
In order to make sure that IOAM is supported, install the iproute2 from:

https://mirrors.edge.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.8.0.tar.xz

Follow the instructions on the README file in the iproute2 folder to make and install.

## Running IOAM-Ping
Run the script:

```
sudo ./ioam-ping.sh
```

The sends 5 ICMP messages and prints the result. It also captures a pcap file.
If everything runs smoothly, you should see something like:

```
PING db01::1 (db01::1) 56 data bytes
152 bytes from db01::1: icmp_seq=1 ttl=64 time=0.192 ms IOAM: NodeID=1,HopLim=64,RcvTime=NA NodeID=2,HopLim=63,RcvTime=1712811441.126
152 bytes from db01::1: icmp_seq=2 ttl=64 time=0.078 ms IOAM: NodeID=1,HopLim=64,RcvTime=NA NodeID=2,HopLim=63,RcvTime=1712811442.129
```

