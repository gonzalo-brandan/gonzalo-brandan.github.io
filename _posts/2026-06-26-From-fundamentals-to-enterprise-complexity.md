---
topic: Projects
title: "Building a new branch office network from scratch"
date: 2026-06-25 16:00:00 +0000
categories: Projects
tags:
  - Cisco
  - ROAS
  - DHCP
  - VLAN
  - Project
  - OSPF
  - PAT
comments: true
toc: true
layout: post
image:
  path: "/assets/img/Pasted image 20260623101319.png"
  alt: "Project network topology"
---
## The idea

Instead of building a new lab every week and throwing it away, I'm building one network and keeping it. It starts simple, and every time I learn something new, I add it. Over time it should become more efficient, more redundant and more secure: from "day 0" to "day N".

On the side I do a lot of troubleshooting exercises that don't make it into the blog. What I learn from breaking things there, I bring back here. This blog is the record of how the network grows.

### The scenario

A company has a **main site** (500 employees) and **Remote Office 1** (220 employees). It's opening **Remote Office 2 (RO2)**, and I'm building that network from scratch.

RO2 starts with four departments. Each one gets its own subnet, and their users are spread across four switches. I also leave room for two more departments later, so six subnets in total.

I split the work into three parts:

1. **The IP plan**: split one `/24` into right-sized subnets with VLSM.
2. **The basics**: cabling, SSH access, VLANs and trunks.
3. **Routing and internet**: OSPF between the three sites, and NAT so RO2 can reach the internet.

## The IP plan

## Addressing Table

![description](/assets/img/Pasted image 20260626163730.png)

Six departments of 30 people each means 180 users. I split `172.20.43.0/24` with VLSM: a `/27` per department (30 usable addresses each, 2⁵−2 = 30), and a smaller `/29` for management.

RO2 subnets (172.20.43.0/24):

| Department | Subnet ID     | Mask | Usable Host Range    | Broadcast     |
| ---------- | ------------- | ---- | -------------------- | ------------- |
| Dept 1     | 172.20.43.0   | /27  | 172.20.43.1 - .30    | 172.20.43.31  |
| Dept 2     | 172.20.43.32  | /27  | 172.20.43.33 - .62   | 172.20.43.63  |
| Dept 3     | 172.20.43.64  | /27  | 172.20.43.65 - .94   | 172.20.43.95  |
| Dept 4     | 172.20.43.96  | /27  | 172.20.43.97 - .126  | 172.20.43.127 |
| Reserve 1  | 172.20.43.128 | /27  | 172.20.43.129 - .158 | 172.20.43.159 |
| Reserve 2  | 172.20.43.160 | /27  | 172.20.43.161 - .190 | 172.20.43.191 |
| Management | 172.20.43.192 | /29  | 172.20.43.193 - .198 | 172.20.43.199 |

That leaves **172.20.43.200 to .255** free for later.

## SSH access

With everything cabled (four departments, six subnets, no config yet), the first job is remote access. SSH, not Telnet: SSH encrypts everything, passwords included.

The router (RO2 as an example):

```
hostname RO2
enable secret cisco123
!
ip domain-name case.study
crypto key generate rsa modulus 2048
ip ssh version 2
!
username admin secret cisco123
!
line vty 0 4
 login local
 transport input ssh
```

A switch (S1 as an example) also needs a management interface (an SVI) and a default gateway, so it can be reached from HQ and RO1:

```
hostname S1
enable secret cisco123
!
ip domain-name case.study
crypto key generate rsa modulus 2048
username admin secret cisco123
!
vlan 99
 name Management
!
interface vlan 99
 ip address 172.20.43.194 255.255.255.248
 no shutdown
!
! Gateway must be the RO2 subinterface for VLAN 99
ip default-gateway 172.20.43.193
!
line vty 0 15
 login local
 transport input ssh
```

I did the same on every router and switch.

## DHCP

All the IP addresses are handed out from one place: **HQ** is the DHCP server, and **RO2** passes the requests along (a "relay"). That way every lease is managed on one device. Later I want to move this to a Windows server.

The switches are the only devices with fixed addresses:

- S1: 172.20.43.194
- S2: 172.20.43.195
- S3: 172.20.43.196
- S4: 172.20.43.197

On HQ, one pool per VLAN. In each pool I exclude the gateway address (RO2's subinterface), so DHCP never gives it to a PC and causes a conflict.

```
! --- Global Exclusions ---
ip dhcp excluded-address 172.20.43.1   ! VLAN 10 Gateway
ip dhcp excluded-address 172.20.43.33  ! VLAN 20 Gateway
ip dhcp excluded-address 172.20.43.65  ! VLAN 30 Gateway
ip dhcp excluded-address 172.20.43.97  ! VLAN 40 Gateway

! --- DHCP Pools ---
ip dhcp pool RO2_VLAN10
 network 172.20.43.0 255.255.255.224
 default-router 172.20.43.1
 dns-server 8.8.8.8

ip dhcp pool RO2_VLAN20
 network 172.20.43.32 255.255.255.224
 default-router 172.20.43.33
 dns-server 8.8.8.8

ip dhcp pool RO2_VLAN30
 network 172.20.43.64 255.255.255.224
 default-router 172.20.43.65
 dns-server 8.8.8.8

ip dhcp pool RO2_VLAN40
 network 172.20.43.96 255.255.255.224
 default-router 172.20.43.97
 dns-server 8.8.8.8
```

There's a catch: a PC asking for an address sends a broadcast, and broadcasts don't cross the WAN to HQ. `ip helper-address` on RO2 fixes that: RO2 catches the broadcast and forwards it to HQ (`172.20.47.249`, HQ's s1/1) as a normal packet.

```
interface Ethernet0/0.10
 ip helper-address 172.20.47.249
!
interface Ethernet0/0.20
 ip helper-address 172.20.47.249
!
interface Ethernet0/0.30
 ip helper-address 172.20.47.249
!
interface Ethernet0/0.40
 ip helper-address 172.20.47.249
```

## Router-on-a-stick

Next, the path between the PCs and the router. With router-on-a-stick, one cable from the switches to RO2 carries all the VLANs.

### Switches

Access ports for the PCs, and trunks between the switches. On every trunk I changed the native VLAN to **999**, an unused VLAN, so untagged traffic doesn't end up anywhere useful. It's a common security practice.

S2 (departments 1 and 2):

```
interface Ethernet0/1
 description Dept_1_Access
 switchport mode access
 switchport access vlan 10
!
interface Ethernet0/2
 description Dept_2_Access
 switchport mode access
 switchport access vlan 20
!
interface Ethernet0/0
 description Trunk_to_S1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,20,99,999
```

S1 collects the traffic from S2, S3 and S4 and sends it to the router, so its trunk to RO2 carries every VLAN:

```
interface Ethernet0/0
 description Trunk_to_RO2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,20,30,40,99,999
```

### The router

On RO2's one physical port I create a **subinterface** per VLAN. Each one is the gateway for its VLAN, and reads the VLAN tag on incoming frames. The VLAN number must match the switches.

```
interface Ethernet0/0.10
 encapsulation dot1q 10
 ip address 172.20.43.1 255.255.255.224
!
interface Ethernet0/0.99
 encapsulation dot1q 99
 ip address 172.20.43.193 255.255.255.248
!
interface Ethernet0/0.999
 description Native_VLAN_Security
 encapsulation dot1q 999 native
```

![description](/assets/img/Pasted image 20260623131201.png)

The four department gateways:

```
interface GigabitEthernet 0/0
 no shutdown
!
interface GigabitEthernet 0/0.10
 encapsulation dot1q 10
 ip address 172.20.43.1 255.255.255.224
!
interface GigabitEthernet 0/0.20
 encapsulation dot1q 20
 ip address 172.20.43.33 255.255.255.224
!
interface GigabitEthernet 0/0.30
 encapsulation dot1q 30
 ip address 172.20.43.65 255.255.255.224
!
interface GigabitEthernet 0/0.40
 encapsulation dot1q 40
 ip address 172.20.43.97 255.255.255.224
```

![description](/assets/img/Pasted image 20260623124604.png)

### When it didn't work: the missing VLANs

My first ping from PC0 (VLAN 10) to RO2 failed. The trunks on S1 were fine, but I'd forgotten to create the VLANs themselves: they didn't show up in `show vlan`. A switch that doesn't know a VLAN drops its traffic, even if the trunk allows it. Once I created them, it worked.

![description](/assets/img/Pasted image 20260623131303.png)

Then VLAN 30 on S3 failed too.

![description](/assets/img/Pasted image 20260623132209.png)

`show vlan` and `show interfaces trunk` showed two problems:

- S3's native VLAN was still the default (1), while S1 used 999.
- S3's e0/0 wasn't a trunk yet, so VLAN 30 had no way out.

![description](/assets/img/Pasted image 20260623132310.png)
![description](/assets/img/Pasted image 20260623132552.png)

I set the trunk and the native VLAN on S3:

![description](/assets/img/Pasted image 20260623132742.png)

Now the trunk is up:

![description](/assets/img/Pasted image 20260623132829.png)

On S1's side (e0/2), the native VLAN didn't match either, and the allowed VLANs weren't set:

![description](/assets/img/Pasted image 20260623133005.png)

So I fixed both:

![description](/assets/img/Pasted image 20260623133139.png)

But the ping still failed. Why?

![description](/assets/img/Pasted image 20260623133212.png)

Same mistake as before: VLAN 30 didn't exist on S1.

![description](/assets/img/Pasted image 20260623133302.png)

I created it:

![description](/assets/img/Pasted image 20260623133329.png)

And the ping works.

![description](/assets/img/Pasted image 20260623133432.png)

Lesson learned: **create the VLANs on every switch they pass through, before anything else.** It's a silly mistake, and I made it twice.

On S3, the next errors:
![description](/assets/img/Pasted image 20260623133738.png)

Fixed by configuring S1's e0/3 properly:
![description](/assets/img/Pasted image 20260623133933.png)

And PC3 in VLAN 40 can reach its gateway on RO2:
![description](/assets/img/Pasted image 20260623134119.png)

### The full test

A ping from department 1 (VLAN 10) to department 4 (VLAN 40):

![description](/assets/img/Pasted image 20260623134536.png)

It works, which shows three things at once:

1. The PCs get their addresses from HQ through the DHCP relay.
2. The switches tag the frames with the right VLAN.
3. RO2 routes between its subinterfaces.

## OSPF between the sites

Now the three sites need to learn each other's networks. I use **multi-area OSPF**: Area 0 is the backbone that connects the offices.

Two choices I made:

- **Router IDs on loopbacks.** A loopback is virtual, so it stays up as long as the router is on. That keeps the OSPF ID stable.
- **Interface-level OSPF.** On RO1 I used the classic `network` command; on the other routers I enable OSPF directly on each interface, which is more precise.

![description](/assets/img/Pasted image 20260623144543.png)

RO1, with the `network` command:
![description](/assets/img/Pasted image 20260623154923.png)
![description](/assets/img/Pasted image 20260623154955.png)
![description](/assets/img/Pasted image 20260623154938.png)

### HQ

![description](/assets/img/Pasted image 20260623155606.png)
(My mistake: s1/1 should be in area 0. Fixed below.)
![description](/assets/img/Pasted image 20260623155751.png)

Two more settings on HQ:

- **Passive interfaces by default.** OSPF is silent everywhere, and I turn it back on only on the WAN links. Routers don't need to send OSPF hellos to user LANs: it wastes CPU, and someone on a LAN could learn the network layout from them.
- **Point-to-point links.** On the WAN links there are only ever two routers, so I tell OSPF that. It skips the "designated router" election and its 40-second wait.

### When it didn't work: a missing IP

With OSPF running on RO1 and HQ, HQ learned RO1's LAN:
![description](/assets/img/Pasted image 20260623160703.png)

But RO1 didn't learn HQ's LAN:
![description](/assets/img/Pasted image 20260623172845.png)

The neighbours were fine:
![description](/assets/img/Pasted image 20260623173012.png)

But on HQ, the protocol was down. Why?
![description](/assets/img/Pasted image 20260623173438.png)

`show ip interface brief` gave two clues:
![description](/assets/img/Pasted image 20260623173603.png)

The LAN interface had no IP address. (The interface to RO2 was down too, but that's for later.) So I fixed e0/1 first:

![description](/assets/img/Pasted image 20260623173707.png)

The mask is /23, so 255.255.254.0. The protocol comes up right away:

![description](/assets/img/Pasted image 20260623173809.png)

And HQ now advertises its LAN to RO1:

![description](/assets/img/Pasted image 20260623174946.png)

A ping from PC4 (RO1) to PC5 (HQ) works:

![description](/assets/img/Pasted image 20260623175652.png)

### RO2

Next, OSPF on RO2:

![description](/assets/img/Pasted image 20260623181529.png)

I make e0/0 passive: there's no other router on that side, so there's no reason to send hellos, and it stops any unknown router from joining.

The neighbour relationship forms, and RO2 learns HQ's routes:

![description](/assets/img/Pasted image 20260624192247.png)

RO2's LAN lives on subinterfaces (no IP on e0/0 itself), so here the `network` command was simpler for advertising it:

![description](/assets/img/Pasted image 20260623181756.png)

HQ learns those routes:

![description](/assets/img/Pasted image 20260624191418.png)

Last, HQ shares its default route (its way to the internet) with `default-information originate`, and it shows up on RO1 and RO2:

![description](/assets/img/Pasted image 20260624192529.png)

## Out to the internet: NAT

But even with the default route, nothing could reach the ISP:

![description](/assets/img/Pasted image 20260624194705.png)

Because the ISP has no route back to my private addresses. HQ has to swap them for its public address on the way out: NAT overload.

![description](/assets/img/Pasted image 20260624195400.png)

Now a ping to 8.8.8.8 (Google DNS) works:

![description](/assets/img/Pasted image 20260624201154.png)

![description](/assets/img/Pasted image 20260624201144.png)

`show ip nat translations` on HQ shows the translations happening:

![description](/assets/img/Pasted image 20260624202223.png)

- **Inside local**: the PC's real private address (here PC0 on RO2's LAN).
- **Inside global**: HQ's public address, what the internet sees as the sender.
- **Outside global**: the destination's public address, here Google DNS.
- **Outside local**: with normal source NAT, the same as outside global.

## Where it stands

RO2 is now part of the company network:

- **Separate departments:** each one in its own VLAN, talking to the others through RO2.
- **Automatic addressing:** HQ hands out every address, with RO2 relaying the requests.
- **Routing:** multi-area OSPF connects all three sites, with stable router IDs and point-to-point WAN links.
- **Internet:** through NAT on HQ.

That's day 0. Next comes making it redundant and more secure.
