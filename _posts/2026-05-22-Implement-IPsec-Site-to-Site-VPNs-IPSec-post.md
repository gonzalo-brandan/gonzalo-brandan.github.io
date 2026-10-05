---
topic: Security
title: "Connecting two offices securely with an IPsec VPN"
date: 2026-05-22 16:00:00 +0000
categories: networking
tags: [ipsec, security, Cisco, Tutorial]
comments: true
toc: true
layout: post
image:
  path: "/assets/img/Pasted image 20260520130556.png"
  alt: "IPsec site-to-site VPN topology"
---

Two offices want to talk to each other over the internet, but nobody in between should be able to read the traffic. That's what a site-to-site VPN is for.

In this lab, R1 and R3 are the two offices, and R2 is the internet provider in the middle. R2 has no idea there's a VPN: it just forwards encrypted packets it can't read.

## Addressing Table

![description](/assets/img/Pasted image 20260520130637.png)

![description](/assets/img/Pasted image 20260520130651.png)

## How it works

Building an IPsec VPN has two parts:

1. **IKE**: the two routers agree on how to protect things and create shared keys. Think of it as a secure handshake.
2. **IPsec**: using those keys, they encrypt the real traffic.

Each part creates a **security association (SA)**: an agreement between the two routers about how traffic is encrypted and checked.

- **Phase 1** (IKE SA): the secure handshake channel.
- **Phase 2** (IPsec SA): the channel that carries the encrypted data.

IPsec works at layer 3 (the network layer), and it's an open framework: new encryption methods can be added as they come out.

IKE is on by default on IOS images with crypto features. If it's off, `crypto isakmp enable` turns it on. If that command gives an error, the router probably needs a different IOS image.

## Step 1: The IKE policy

`crypto isakmp policy <number>` creates a policy. The number also sets its priority: the router tries policy 1 first, then 2, and so on.

I create policy 10 and type `?` to see the options:

![description](/assets/img/Pasted image 20260522121151.png)

These are the minimum recommended settings:

![description](/assets/img/Pasted image 20260522121253.png)

A new policy starts with default values. `do show crypto isakmp policy` shows them:

![description](/assets/img/Pasted image 20260522121700.png)

The defaults (in the red box) are too weak, so I change most of them.

### What each setting does

- **Encryption**: keeps the handshake messages secret.
- **Hash**: makes sure nothing was changed on the way.
- **Authentication**: proves the other side is really who it says it is.
- **Diffie-Hellman group**: lets both routers create the same secret key without ever sending it over the network.

What I use on both R1 and R3:

- Encryption: AES-256
- Hash: SHA-256
- Authentication: pre-shared key
- Diffie-Hellman group: 14
- Lifetime: 3600 seconds (60 minutes)

![description](/assets/img/Pasted image 20260522122908.png)

![description](/assets/img/Pasted image 20260522123121.png)

Checking again with `show crypto isakmp policy`:

![description](/assets/img/Pasted image 20260522123247.png)

![description](/assets/img/Pasted image 20260522123318.png)

The policy has to be the same on both routers.

## Step 2: The pre-shared key

Since the policy uses a pre-shared key, each router needs the key and the address of the other side:

`crypto isakmp key <key-string> address <ip-address>`

The address is the other router's outside (internet-facing) interface. You can also use `0.0.0.0 0.0.0.0` to accept any peer, which is handy when the other side's IP changes or when many peers share one key.

R3's outside interface is `e0/0`, with `64.100.1.2`:

![description](/assets/img/Pasted image 20260522124614.png)

So on R1 the key points to that address:

![description](/assets/img/Pasted image 20260522124659.png)

And on R3, it points to R1's outside address:

![description](/assets/img/Pasted image 20260522124845.png)

Both together:

![description](/assets/img/Pasted image 20260522124925.png)

(A real network would use a much longer key.)

## Step 3: The transform set

The IKE policy protects the handshake. The **transform set** decides how the actual data is protected.

`crypto ipsec transform-set <transform-set-name> <transform1> [transform2]`

I create one called `S2S-VPN` and check the options:

![description](/assets/img/Pasted image 20260522131707.png)

What the options mean:

- **`ah-…`**: Authentication Header. Checks the packets but doesn't encrypt them.
- **`esp-…`**: Encapsulating Security Payload. Can encrypt, check, or both.
- **`…-hmac`**: a check that the packet is genuine and wasn't changed.
- **`esp-aes`, `esp-3des`, `esp-des`**: the encryption itself.

`R1(config)# crypto ipsec transform-set S2S-VPN esp-aes 256 esp-sha256-hmac`

`R3(config)# crypto ipsec transform-set S2S-VPN esp-aes 256 esp-sha256-hmac`

The transform set doesn't have to match the IKE policy. It only has to match on both routers.

## Step 4: Choose which traffic to encrypt

The router needs to know which traffic should go through the tunnel. An extended ACL picks it out. Traffic the ACL doesn't match isn't dropped; it just goes out normally, unencrypted.

From R1's side, that's traffic from R1's LANs to R3's LANs. R3 needs the mirror image: same networks, source and destination swapped.

### On R1

![description](/assets/img/Pasted image 20260522133605.png)

### On R3

![description](/assets/img/Pasted image 20260522133719.png)

If the two ACLs don't mirror each other, the tunnel can still come up, but your traffic won't match it and will skip the encryption. Easy to miss.

## Step 5: The crypto map

The crypto map ties everything together: which traffic (the ACL), to which peer, with which transform set. Then it goes on the interface facing the other office.

`crypto map <name> <sequence-number> ipsec-isakmp`

On R1: name `S2S-CMAP`, sequence `10`, type `ipsec-isakmp` (meaning IKE sets up the tunnel).

![description](/assets/img/Pasted image 20260522134815.png)

Which traffic to encrypt (the ACL):

![description](/assets/img/Pasted image 20260522134921.png)

Who the peer is (R3's outside interface):

![description](/assets/img/Pasted image 20260522135039.png)

Which transform set to use:

![description](/assets/img/Pasted image 20260522135328.png)

The same on R3, mirrored:

![description](/assets/img/Pasted image 20260522135600.png)

And finally, the crypto maps go on the interfaces:

![description](/assets/img/Pasted image 20260522135726.png)

![description](/assets/img/Pasted image 20260522135700.png)

## Does it work?

Two useful commands:

`show crypto ipsec transform-set S2S-VPN`
`show crypto map`

![description](/assets/img/Pasted image 20260522140242.png)

![description](/assets/img/Pasted image 20260522140341.png)

At first, `show crypto isakmp sa` shows nothing. That's normal: the tunnel only comes up when there's traffic to encrypt.

![description](/assets/img/Pasted image 20260522140402.png)

After sending some traffic between the LANs, the security associations appear:

![description](/assets/img/Pasted image 20260522140714.png)

And the same on R3:

![description](/assets/img/Pasted image 20260522140850.png)

The tunnel is up and the traffic is encrypted.

## What I took from it

A site-to-site VPN is built in layers: IKE makes the secure handshake, then IPsec protects the data, while the provider in the middle just forwards packets it can't read.

Everything has to match on both sides: the IKE policy, the transform set, and the mirrored ACLs. And seeing the security associations appear the moment traffic started flowing was a satisfying way to know all the pieces finally worked together.
