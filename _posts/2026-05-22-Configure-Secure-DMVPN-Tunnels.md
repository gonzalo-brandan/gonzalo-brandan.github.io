In this lab, I explore how to secure a DMVPN Phase 3 network with IPsec. DMVPN dynamically builds GRE tunnels between hub and spokes, while IPsec encrypts the traffic running over them. I start by verifying the existing DMVPN setup, then configure IKE policies and IPsec protection on the hub and spokes, and finally check that the SAs are established and the spoke‑to‑spoke tunnels work as expected.

![[Pasted image 20260522143349.png]]

![[Pasted image 20260522143403.png]]

IPsec functionality is essential to DMVPN implementation. 

## Step 1: Verify DMVPN operation

I will ping the loopback addresses of R2 and R3 from R1 and use the sh dmvpn command

![[Pasted image 20260522144705.png]]

## Step 2: Secure DMVPN Phase 3 Tunnels

First I have to create the IKE policy that defines the hash algorithm, encryption type, key exchange method, Diffie-Hellman group, and the authentication method

IKE (Internet Key Exchange) is the protocol that **sets up and manages the secure “handshake”** between two devices before an IPsec VPN tunnel can protect real data.

![[Pasted image 20260522145107.png]]

this block configures **IKE Phase 1 parameters** on R1 so that when it talks to R3, both routers agree on the same hash, encryption, key‑exchange group, and authentication method to build the secure control channel.

I have created an IKE/ISAKMP policy with number **99**, which uniquely identifies this policy and gives it a priority (higher numbers = lower priority).

It's time to create the pre-shared key and peer address. I will use 0.0.0.0 to match multiple peer addresses, and use DMVPN@key# as the key.

![[Pasted image 20260522191941.png]]

Now I will configure the IPsec transform set. 

![[Pasted image 20260522192345.png]]

There is two modes for the tunnel, can be either transport and tunnel.

- **Tunnel mode**: The whole original packet is hidden inside a new IP packet, so only the VPN endpoints’ IPs are visible on the network.
    
- **Transport mode**: Only the data inside the packet is encrypted; the original sender and receiver IPs stay visible and unchanged.

I create an **IPsec profile** that “bundles” the IPsec protection settings and can later be applied to a tunnel interface.

![[Pasted image 20260522192833.png]]

the **IPsec profile** is like a “template” that says “when you apply me to a tunnel, protect that tunnel with transform set `DMVPN_TRANS`"

The command to apply the IPsec profile to an interface is **tunnel protection ipsec profile** *profile-name*

![[Pasted image 20260522193644.png]]

In this case, the routers are running EIGRP, but since R2 and R3 are not yet configured with IPsec, they fail to establish both the EIGRP neighbor adjacency and the IPsec security association.

I will now configure IPsec properly on R2 and R3. Since the hub’s interface has a dynamic IP address, I will use 0.0.0.0 0.0.0.0 as the address; otherwise, I would use the hub’s public IP address.

On R2 and R3: 

![[Pasted image 20260522194949.png]]

Tip: To help me remember these four steps, I think of it like this: I use the crypto isakmp command twice (for policies and pre‑shared keys) and the crypto ipsec command twice (for the transform set and the profile), and then I apply the IPsec profile to the tunnel interface.

Now coming back to R1 and checking for the security associations, I check that the SAs with R2 and R3 are formed correctly, which they are

![[Pasted image 20260522195246.png]]

Another command I can use is show crypto ipsec sa.  It shows **IPsec Phase 2 SAs**: the security associations that actually encrypt and authenticate the **data traffic** (packets)

![[Pasted image 20260522200020.png]]

First address corresponds to R1 and second one with R3, below R2 will appear too.

To finish I use traceroute from R2 to the simulated LAN interface on R3. Then I issue the traceroute command again. I will now see that R1 has enabled direct spoke-to-spoke
communication between R2 and R3. This tunnel will expire and close dynamically. The tunnel reopens after data for the spoke router is sent again.

![[Pasted image 20260522200419.png]]


In the end, this lab showed me how DMVPN and IPsec work together: DMVPN dynamically builds the GRE tunnels, and IPsec protects them with strong encryption and IKE negotiation. 

Here are my three **must‑remember takeaways** for this lab:

1. **IKE and IPsec are separate layers**:  
    First you configure **IKE (ISAKMP)** to set up the secure control channel; then you configure **IPsec (transform set + profile)** to protect the actual data traffic.
    
2. **The hub uses `0.0.0.0` for dynamic spokes**:  
    On the hub, using `crypto isakmp key ... address 0.0.0.0 0.0.0.0` lets one pre‑shared key work with many spokes, which is especially useful in DMVPN with dynamic IP addresses.
    
3. **Always check both SA types**:  
    Use `show crypto isakmp sa` to confirm the IKE‑phase tunnel is up, and `show crypto ipsec sa` to confirm that real data is being encrypted between the peers.