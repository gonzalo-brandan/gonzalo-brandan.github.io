

In the [last post](/posts/configure-a-basic-wlan-on-the-wlc/) everyone shared one Wi-Fi password. That's fine at home, but in a company it's a problem: if one person leaves, you have to change the password for everyone.

This time each person logs in with their own account, checked by a RADIUS server (WPA2-Enterprise). I also set up DHCP on the controller and point it at a monitoring server with SNMP.

Topology:

![description](/assets/img/Pasted image 20251126134551.png)

#### Personal vs Enterprise

|  | WPA2-Personal | WPA2-Enterprise |
|---|---|---|
| How you log in | One shared password for everyone | Your own username and password (or a certificate), checked by a RADIUS server (802.1X) |
| Good | Easy to set up. Fine for home or a tiny office. | Much safer. You can see who connected, and remove one person without affecting anyone else. Scales to a whole company. |
| Not so good | Everyone has the same key. You can't tell who is who. | You need a RADIUS server, and it takes a bit more setup. |

The server also logs who connected and when, which helps with troubleshooting, security audits and compliance.

#### How a WLAN reaches the wired network

Each Wi-Fi network on the controller is linked to a VLAN. When someone connects to it, their traffic goes into that VLAN.

A company usually has several Wi-Fi networks (staff, guests, IoT…), so several VLANs travel together over the same cables. That's why the links between the APs, the controller and the router are **trunks**: one cable carries many VLANs, each kept separate.

## Part 1: The WLAN

### 1. Create a VLAN interface

I log in to the controller from the Admin PC (`https://` and the management IP).

![description](/assets/img/Pasted image 20251126134907.png)

Under **Controller → Interfaces** there's already the management interface (the one I'm using right now) and the virtual interface. I click **New**.

![description](/assets/img/2025-11-26_13-55.png)

I give it a name and a VLAN ID. This is the VLAN the new Wi-Fi network will use.

![description](/assets/img/Pasted image 20251126135834.png)

Then I set it up: physical port 1, the 192.168.5.0/24 network, and router R-1 as the DHCP server for these clients. Several VLAN interfaces can share port 1, because the controller's physical ports work like trunks.

![description](/assets/img/Pasted image 20251126140342.png)

### 2. Tell the controller about the RADIUS server

The controller doesn't check passwords itself; it asks the RADIUS server. So first it needs to know where that server is.

Under **Security**, I click **New…**

![description](/assets/img/2025-11-26_14-23.png)

I enter the server's IP and a shared secret. The secret is how the server knows the controller is allowed to ask it about user accounts.

![description](/assets/img/Pasted image 20251126142829.png)

The server shows up in the list:

![description](/assets/img/Pasted image 20251126143310.png)

### 3. Create the WLAN

Under **WLANs**, I create a new one.

![description](/assets/img/2025-11-26_14-35.png)

Profile name, SSID and ID, then Apply.

![description](/assets/img/Pasted image 20251126143752.png)

I enable it and pick the interface from step 1, so its users land in that VLAN.

![description](/assets/img/Pasted image 20251126144014.png)

### 4. Turn on WPA2-Enterprise

In **Security → Layer 2** I choose WPA+WPA2, with WPA2 and **802.1X**, which means "send logins to an external server". In the **AAA Servers** tab I pick the RADIUS server from step 2.

![description](/assets/img/Pasted image 20251126144446.png)
![description](/assets/img/Pasted image 20251126144516.png)

---------

## Part 2: DHCP and SNMP

### 1. DHCP on the controller

The controller has its own small DHCP server. It's not meant for lots of users, but it's handy for giving addresses to the access points on the management network. Here I use it to give LAP-1 an address.

Under **Controller → Interfaces** there are three kinds of interface:

- **Management**: for the web GUI, and where the APs join the controller (CAPWAP).
- **Dynamic** (like WLAN-5): link each Wi-Fi network to a VLAN.
- **Virtual**: for the controller's internal jobs (DHCP relay, web login, roaming). It carries no user traffic and doesn't exist on the wired network.

The management interface:

- IP address: 192.168.200.254
- Netmask: 255.255.255.0
- Gateway: 192.168.200.1
- Primary DHCP server: 0.0.0.0

![description](/assets/img/2025-11-26_14-55.png)

I set the controller itself as the DHCP server for this network, so when an AP asks for an address, the controller answers.

![description](/assets/img/2025-11-26_15-23.png)

Then I create a scope called **Wired Management**: a small range of addresses for LAP-1, other management devices and future APs.

![description](/assets/img/2025-11-26_15-25.png)![description](/assets/img/Pasted image 20251126152640.png)
![description](/assets/img/Pasted image 20251126152743.png)

The network and netmask have to match the management interface, because this scope is for the management VLAN only, not for users.

![description](/assets/img/Pasted image 20251126153048.png)

The scope is ready. Management devices in that VLAN now get an address from it.

![description](/assets/img/Pasted image 20251126153547.png)

### 2. SNMP

SNMP lets a monitoring system keep an eye on the controller. When something happens, the controller sends a message (a "trap") to the monitoring server.

Under **Management → SNMP → Trap Receivers** I click **New…**. This is where you tell the controller where to send those messages.

![description](/assets/img/2025-11-26_16-30.png)

A community name and the server's IP:

![description](/assets/img/Pasted image 20251126163425.png)

And it's in the list:

![description](/assets/img/Pasted image 20251126163907.png)

### 3. Connect a laptop

With WPA2-Enterprise you can't just click the network and type a password. In Packet Tracer the laptop needs a **profile** with the login details. I open **Profiles** in the PC's wireless settings.

![description](/assets/img/Pasted image 20251126164233.png)

I name the profile.

![description](/assets/img/Pasted image 20251126164352.png)

In **Advanced Setup**:

![description](/assets/img/Pasted image 20251126164451.png)

I enter the Wi-Fi network name, then the login settings.

![description](/assets/img/Pasted image 20251126164558.png)
![description](/assets/img/Pasted image 20251126164939.png)![description](/assets/img/Pasted image 20251126164948.png)
![description](/assets/img/Pasted image 20251126165035.png)

![description](/assets/img/Pasted image 20251127093510.png)

![description](/assets/img/Pasted image 20251126111200.png)

It connects to the access point and gets an IP from DHCP. Done.

### What I learned

- Per-user logins with RADIUS scale much better and are safer than a shared password.
- How the controller's built-in DHCP works, and how to set up a pool.
- SNMP traps (**Management → SNMP → Trap Receivers**) let a monitoring server keep an eye on the controller.
