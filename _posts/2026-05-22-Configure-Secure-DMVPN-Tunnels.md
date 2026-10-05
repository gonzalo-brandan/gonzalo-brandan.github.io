---
topic: Security
title: "Encrypting DMVPN tunnels between a head office and its branches"
date: 2026-05-22 16:00:00 +0000
categories: networking
tags: [ipsec, dmvpn, Cisco, Tutorial]
comments: true
toc: true
layout: post
image:
  path: "/assets/img/Pasted image 20260522143349.png"
  alt: "DMVPN lab topology"
---
DMVPN connects a head office (the hub) with branches (the spokes) over the internet, and lets branches talk to each other directly, without going through the hub. But on its own, DMVPN doesn't encrypt anything: the GRE tunnels it builds travel across the internet in plain text.

So in this lab I add IPsec on top. DMVPN builds the tunnels, and IPsec locks them.

![description](/assets/img/Pasted image 20260522143403.png)

## Step 1: Check that DMVPN works

Before adding encryption, I make sure the tunnels are up. From R1 (the hub) I ping the loopbacks of R2 and R3 and run `show dmvpn`.

![description](/assets/img/Pasted image 20260522144705.png)

## Step 2: Add IPsec

Securing the tunnels takes four pieces of config, then one line to apply them.

### 1. The IKE policy

Before two routers encrypt anything, they need to agree on *how*: which encryption, which hash, which key exchange. That "handshake" is IKE.

![description](/assets/img/Pasted image 20260522145107.png)

This is policy number **99**. The number just identifies it and sets its priority: lower numbers are tried first.

### 2. The pre-shared key

Both sides prove who they are with the same key, here `DMVPN@key#`. The address `0.0.0.0` means "accept this key from any peer", which is what you want on a hub with many spokes.

![description](/assets/img/Pasted image 20260522191941.png)

### 3. The transform set

This says how the actual traffic will be protected.

![description](/assets/img/Pasted image 20260522192345.png)

IPsec has two modes:

- **Tunnel mode**: the whole original packet is wrapped inside a new one. Only the two VPN routers' addresses are visible.
- **Transport mode**: only the data is encrypted. The original sender and receiver addresses stay visible.

### 4. The IPsec profile

A profile is a template: "whatever tunnel I'm applied to, protect it with the transform set `DMVPN_TRANS`."

![description](/assets/img/Pasted image 20260522192833.png)

### Apply it to the tunnel

One command on the tunnel interface:

`tunnel protection ipsec profile <profile-name>`

![description](/assets/img/Pasted image 20260522193644.png)

At this point the hub is encrypting, but R2 and R3 aren't yet. They don't understand each other, so both the EIGRP neighbours and the IPsec sessions fail. Expected.

### Same on the spokes

On R2 and R3 I add the same config. The hub's interface has a dynamic IP, so the spokes also use `0.0.0.0 0.0.0.0` as the peer address. If the hub had a fixed public IP, I'd use that instead.

![description](/assets/img/Pasted image 20260522194949.png)

**How I remember it:** `crypto isakmp` twice (the policy and the key), `crypto ipsec` twice (the transform set and the profile), then apply the profile to the tunnel.

## Step 3: Check that it's encrypted

Back on R1, `show crypto isakmp sa` shows the handshakes with R2 and R3 are up.

![description](/assets/img/Pasted image 20260522195246.png)

And `show crypto ipsec sa` shows the sessions that actually encrypt the data:

![description](/assets/img/Pasted image 20260522200020.png)

The first address is R1 and the second is R3. R2 appears below.

Last, the fun part. I run a traceroute from R2 to a LAN on R3. The first time, the traffic goes through the hub. The second time, it goes straight from R2 to R3: the hub has helped them build a direct, encrypted tunnel.

That direct tunnel closes on its own when it's not used, and reopens as soon as the spokes talk again.

![description](/assets/img/Pasted image 20260522200419.png)

## What to remember

1. **IKE and IPsec are two different steps.** IKE sets up the secure handshake; IPsec (transform set and profile) protects the real traffic.
2. **`0.0.0.0` on the hub** lets one key work for every spoke, even when their addresses change.
3. **Check both:** `show crypto isakmp sa` for the handshake, `show crypto ipsec sa` to see that traffic is really being encrypted.
