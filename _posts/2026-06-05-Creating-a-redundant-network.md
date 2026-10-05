---
topic: Networking
title: "Building a network that keeps working when things break"
date: 2026-06-04 16:00:00 +0000
categories: networking
tags: [redundancy, VLAN, NAT, HSRP, BGP, Cisco, Tutorial]
comments: true
toc: true
layout: post
image:
  path: "/assets/img/Pasted image 20260605145741.png"
  alt: "Redundant enterprise network topology"
---

What happens to a network when something breaks? In this lab I built one where almost anything can fail (a cable, a switch, a router, even a whole internet provider) and people can keep working.

I built it in Packet Tracer, layer by layer, from the internet down to the PCs: two ISPs, two edge routers, two core switches, three access switches, Wi-Fi and the users. Then I switched things off to see if it held.

I followed Dan Miller's [Cisco Packet Tracer Lab Mastery](https://www.packtpub.com/en-us/product/cisco-packet-tracer-lab-mastery-build-and-secure-advanced-topologies-9781806708390) as a guided exercise. This post is my notes from building it.

## The design

### Two internet providers

![description](/assets/img/Pasted image 20260601172800.png)

Real redundancy means two providers, not just two cables. If both links run through the same provider and that provider goes down, you lose both.

So I used two ISPs:

- **ISP1**, the main one: fiber, 1 Gbps, 99.99% uptime.
- **ISP2**, the backup: VDSL, 100 Mbps, 99.9% uptime.

Each one has a loopback that stands in for "the internet", and they talk to my routers with BGP, the same way real providers do.

### Two routers at the edge

![description](/assets/img/Pasted image 20260601174015.png)

Two providers don't help much if everything still goes through one router. If that router dies, you're offline anyway.

So I added a second one. With HSRP, both routers share one "virtual" gateway address. The network only knows that address, so if one router goes down, the other takes over and nobody notices.

### Two core switches

![description](/assets/img/Pasted image 20260601175416.png)

The core is where all the traffic meets, so one core switch would be one big weak spot. I used two, in a collapsed core (core and distribution in the same switches, which keeps it simple).

The edge routers connect to the core through VLAN 99 and share the virtual gateway 10.99.99.254. At this stage spanning tree blocks one of the links between the two cores. That's expected: the port-channel that fixes it comes later.

### Access switches

![description](/assets/img/Pasted image 20260601192130.png)

This is where PCs, phones, printers and access points plug in. If an access switch has one cable to the core and that cable fails, everyone on it is offline. So each access switch has uplinks to **both** core switches.

The access switches don't connect to each other. User traffic always goes up through the core.

### The users

![description](/assets/img/Pasted image 20260601193543.png)

PCs, IP phones, printers, a server and wireless devices, spread across floors like a real office. At some desks the PC plugs into the phone, so one cable carries both voice and data.

Users don't need the same level of redundancy as the core. Their connections just need to be stable and in the right VLAN.

### Wi-Fi

![description](/assets/img/Pasted image 20260601194808.png)
![description](/assets/img/Pasted image 20260601194829.png)

A wireless controller (WLC) runs all the access points, so it's another single point of failure. I modelled an active/passive pair and put the APs on different floors, with overlapping coverage, so one AP going down doesn't leave a dead zone.

Packet Tracer can't simulate Wi-Fi very realistically, so this part is more about the design than the configuration.

### VLANs and IP plan

![description](/assets/img/Pasted image 20260601195810.png)

Three VLANs, one subnet each:

| VLAN | For | Subnet |
|---|---|---|
| 10 | Wired staff | 192.168.10.0/24 |
| 20 | Voice (IP phones) | 192.168.20.0/24 |
| 30 | Wireless staff | 192.168.30.0/24 |

In every VLAN, Core1 is `.1`, Core2 is `.2`, and `.254` is the shared HSRP gateway the devices use.

## Building it

### ISPs

![description](/assets/img/Pasted image 20260601205442.png)
![description](/assets/img/Pasted image 20260601205556.png)

I started at the internet side, so the outside world was ready before building inwards. ISP1 is in BGP AS 100 and ISP2 in AS 200. Each advertises its loopback and the link to its edge router.

### Edge routers

Edge1

![description](/assets/img/Pasted image 20260602141045.png)

Edge2
![description](/assets/img/Pasted image 20260602141141.png)

Each edge router connects to its ISP, and the two share the inside gateway with HSRP. Edge1 has the higher priority, so it's active; Edge2 waits on standby.

I checked that both could reach their ISP before going further. No point building the inside if the outside doesn't work. For now the link between them used VLAN 1, just to test that HSRP failover worked. It moves to VLAN 99 later.

Verification:
![description](/assets/img/Pasted image 20260602152342.png)

I did the same check on Edge2.

### Core switches

First, the link between the two cores: two cables bundled into one port-channel, carrying VLAN 99.

Core1
```
interface Port-channel1
 description Uplink to Core2
 switchport trunk native vlan 99
 switchport trunk allowed vlan 99
 switchport mode trunk
!
interface GigabitEthernet1/0/1
 switchport access vlan 99
 switchport mode access
!
interface GigabitEthernet1/0/23
 switchport trunk native vlan 99
 switchport trunk allowed vlan 99
 switchport mode trunk
 channel-group 1 mode active
!
interface GigabitEthernet1/0/24
 switchport trunk native vlan 99
 switchport trunk allowed vlan 99
 switchport mode trunk
 channel-group 1 mode active
```

Core2 gets the same configuration.

This moves the HSRP traffic between the routers off VLAN 1 and onto its own VLAN 99, away from user traffic. The routers don't need to know about VLAN 99: the switch port they plug into puts their traffic in it. And with two cables in a port-channel, the core-to-core link survives one cable failing.

Verification
![description](/assets/img/Pasted image 20260602174124.png)

Next, the user VLANs. The cores are the gateway for the users, so I created VLANs 10, 20 and 30 on both and turned on routing between them with `ip routing`.

![description](/assets/img/Pasted image 20260602190113.png)

Then each VLAN gets a gateway IP and HSRP, so the two cores share one virtual gateway per VLAN. Core1 is active (priority 110), Core2 is standby (priority 90):

```
interface Vlan10
 ip address 192.168.10.1 255.255.255.0   // .2 on Core2
 standby version 2
 standby 10 ip 192.168.10.254
 standby 10 priority 110                 // 90 on Core2
 standby 10 preempt
!
interface Vlan20
 ip address 192.168.20.1 255.255.255.0   // .2 on Core2
 standby version 2
 standby 20 ip 192.168.20.254
 standby 20 priority 110                 // 90 on Core2
 standby 20 preempt
!
interface Vlan30
 ip address 192.168.30.1 255.255.255.0   // .2 on Core2
 standby version 2
 standby 30 ip 192.168.30.254
 standby 30 priority 110                 // 90 on Core2
 standby 30 preempt
```

![description](/assets/img/Pasted image 20260602192443.png)

I created the same three VLANs on all three access switches, so every floor looks the same.

![description](/assets/img/Pasted image 20260602205947.png)

### Access ports

![description](/assets/img/Pasted image 20260603144654.png)

Each device goes in its VLAN: wired PCs in 10, phones in 20 (with the PC behind them still in 10), wireless in 30.

### Connecting access to core

Access3
![description](/assets/img/Pasted image 20260603163037.png)
Core1
![description](/assets/img/Pasted image 20260603163122.png)

The VLANs existed on every switch, but nothing carried them between switches yet. So each access switch connects to each core with a port-channel trunk carrying VLANs 10, 20 and 30 (native VLAN 10).

Core
```
### CORE1

interface range GigabitEthernet1/0/10-11
 channel-group 11 mode active
interface range GigabitEthernet1/0/12-13
 channel-group 12 mode active
interface range GigabitEthernet1/0/14-15
 channel-group 13 mode active

interface port-channel 11
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 12
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 13
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30

### CORE2

interface range GigabitEthernet1/0/12-13
 channel-group 14 mode active
interface range GigabitEthernet1/0/14-15
 channel-group 15 mode active
interface range GigabitEthernet1/0/16-17
 channel-group 16 mode active

interface port-channel 14
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 15
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 16
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
```

Access
```
### ACCESS1

interface range Fa0/10-11
 channel-group 1 mode active
interface range Fa0/12-13
 channel-group 2 mode active

interface port-channel 1
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 2
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30

### ACCESS2

interface range Fa0/12-13
 channel-group 1 mode active
interface range Fa0/14-15
 channel-group 2 mode active

interface port-channel 1
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 2
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30

### ACCESS3

interface range Fa0/14-15
 channel-group 1 mode active
interface range Fa0/16-17
 channel-group 2 mode active

interface port-channel 1
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
interface port-channel 2
 switchport mode trunk
 switchport trunk native vlan 10
 switchport trunk allowed vlan 10,20,30
```

Now the VLANs work end to end.

### DHCP and DNS

The server gets a static IP and handles DNS, plus a DHCP pool for each VLAN, each pointing at that VLAN's HSRP gateway.

![description](/assets/img/Pasted image 20260603173541.png)

Configuring DHCP and DNS on the server:

DHCP for WiredStaff VLAN
![description](/assets/img/Pasted image 20260603174552.png)

DHCP for WiredVoIP VLAN
![description](/assets/img/Pasted image 20260603174507.png)

DHCP for WirelessStaff VLAN
![description](/assets/img/Pasted image 20260603174432.png)

## Getting out to the internet

### Routing

Inside, everything worked: users could reach the access and core switches.

![description](/assets/img/Pasted image 20260605112546.png)

But nothing could reach the edge routers or the ISPs.

![description](/assets/img/Pasted image 20260605112720.png)

The reason: the cores only knew about their three local VLANs, and nothing else.

![description](/assets/img/Pasted image 20260605112836.png)

Traffic needs a path in both directions. A bigger network would use a dynamic routing protocol here; for the lab, static routes do the job.

**From the core out:** a default route on both cores, pointing at the edge routers' shared gateway:

`ip route 0.0.0.0 0.0.0.0 10.99.99.254`

**From the edge back in:** static routes to the three VLANs, plus a default route to the ISP.

On Edge1:
```
ip route 192.168.10.0 255.255.255.0 10.99.99.201
ip route 192.168.20.0 255.255.255.0 10.99.99.201
ip route 192.168.30.0 255.255.255.0 10.99.99.201
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/0/0
```

On Edge2:
```
ip route 192.168.10.0 255.255.255.0 10.99.99.202
ip route 192.168.20.0 255.255.255.0 10.99.99.202
ip route 192.168.30.0 255.255.255.0 10.99.99.202
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/0/0
```

For the cores to reach 10.99.99.254, they also need an address in VLAN 99:

Core1:
![description](/assets/img/Pasted image 20260605120456.png)

Core2:
![description](/assets/img/Pasted image 20260605120521.png)

Now the PCs could ping the edge routers, but still not the ISPs:
![description](/assets/img/Pasted image 20260605124755.png)

### NAT

The last missing piece. The ISPs have no idea what 192.168.x.x is, so the edge routers have to swap the private addresses for their public one on the way out. With PAT, every inside device shares that one public IP.

Edge1 and Edge2:
```
access-list 1 permit 192.168.10.0 0.0.0.255
access-list 1 permit 192.168.20.0 0.0.0.255
access-list 1 permit 192.168.30.0 0.0.0.255
access-list 1 permit 10.99.99.0 0.0.0.255
!
ip nat inside source list 1 interface GigabitEthernet0/0/0 overload
!
interface GigabitEthernet0/0/0
 ip nat outside
interface GigabitEthernet0/0/1
 ip nat inside
```

And now we have internet, including name resolution through DNS (pinging from PC0):

![description](/assets/img/Pasted image 20260605125657.png)

![description](/assets/img/Pasted image 20260605130109.png)

## Breaking it on purpose

![description](/assets/img/Pasted image 20260605132716.png)

The real test: I started a continuous ping from a PC and shut down Core1.

![description](/assets/img/Pasted image 20260605140405.png)

The few timeouts are the moment Core1 went down. Then Core2 took over and the pings came back on their own.

![description](/assets/img/Pasted image 20260605140729.png)

One thing I had to fix along the way: I needed a BGP session between ISP1 and ISP2.

![description](/assets/img/Pasted image 20260605140831.png)

## What I took from it

Redundancy only works if it exists at every layer. Two ISPs don't help with one edge router, and two cores don't help if an access switch has a single uplink. The weak spot is always the one layer you didn't double.

And watching the pings come back after switching off a core switch is very satisfying.
