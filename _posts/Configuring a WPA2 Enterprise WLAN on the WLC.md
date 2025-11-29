In this lab, I will configure a new WLAN on a WLC, including the VLAN interface that it will use. I will configure the WLAN to use a RADIUS server and WPA2-Enterprise to authenticate users. I will also configure the WLC to use an SNMP server.

Topology:

![[Pasted image 20251126134551.png]]

This new excercise will use a RADIUS server and WPA2-Enterprise. The benefits of it are: it alow the administration of user accounts from a central location and provides enhanced security and transparency because each account has its own username and password. In addition, user activity is logged on the server (useful for non-repudiation, security auditing, troubleshooting, user accountability, and meeting compliance requirements)

#### Differences between WPA2-Personal and WPA2-Enterprise:

|             | WPA2-Personal                                                                                                                                                   | WPA2-Enterprise                                                                                                                                                                                                                               |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth method | Uses a single shared password (Pre-shared Key)<br>for all users.                                                                                                | Uses a RADIUS server (802.1X).<br>Each user has their own username and password (or certificate)                                                                                                                                              |
| Pros        | Easy to configure.<br>Good for home or very small networks.                                                                                                     | Much stronger security.<br>Per-user authentication, logs, and accountability.<br>Easy to revoke access to a single user.<br>Works well for organizations with many employees.<br>Supports certificate-based authentication (even more secure) |
| Cons        | EVeryone shares the same password (Low security)<br>No per-user visibility or accountability.<br>Hard to remove access for one person without affecting others. | Requires a RADIUS server (more setup and management)<br>Slightly more complex configuration.                                                                                                                                                  |


A **WLAN on a WLC needs a dynamic interface**, which is basically a virtual/logical interface mapped to a **specific VLAN ID**. When wireless clients connect to that WLAN, their traffic is placed into that VLAN and **tagged with that VLAN ID**.

Because multiple WLANs usually exist (Employees, Guests, IoT, etc.), the WLC and APs must be able to carry traffic for **many VLANs at the same time**. This is why the links between the APs, the WLC, and the router are configured as **trunk ports**.

A trunk port can transport **multiple VLANs simultaneously**, keeping each WLAN’s traffic separated while traveling through the wired network.

So in short:

- **WLAN -> mapped to a VLAN**
- **Traffic tagged with that VLAN ID**
- **Trunk ports required** to carry all those VLANs across the infrastructure.

This ensures proper segmentation, security, and routing for each wireless network.

1. Create a new VLAN interface
   
   From the Admin PC I access to the WLCs GUI using the web browser, https and the WLC management IP address. I authenticate.

![[Pasted image 20251126134907.png]]

Clicking on the Controller menu and then on the Interfaces submenu I see the default virtual interface and the management interface (the one I am connected right now). I do then click on the **New** button (on the upper right corner) in order to set up a new Interface.

![[2025-11-26_13-55.png]]

Then I assign a name and a VLAN ID to the interface. This is the VLAN that will carry traffic for the WLAN that will be created later.

![[Pasted image 20251126135834.png]]


I will be then sent to the configuration screen for this VLAN interface.
I will configure the interface to use the physical port number 1. Multiple VLAN interfaces can use the same physical port because the physical interfaces are like dedicated trunk ports.

I will configure the VLAN interface to be on the 192.168.5.0/24 network. The DHCP requests from hosts on the WLAN will be forward to the R-1 router. 

![[Pasted image 20251126140342.png]]

2. Configure the WLC to use a RADIUS server

WPA2-Enterprise uses an external RADIUS server to authenticate WLAN users. Before the WLC can use the services of the RADIUS server, the WLC must be configured with the server address.

In order to do that, I go into the Security menu, and I click on New...

![[2025-11-26_14-23.png]]

I enter the RADIUS server IP address. The RADIUS server will authenticate the WLC before it will allow to access the user account information that is on the server, therefore a shared secret value is required. I apply the set up.

![[Pasted image 20251126142829.png]]

Going back to the Security menu, I verify that the RADIUS server has been added.

![[Pasted image 20251126143310.png]]

3. Create a new WLAN.

I will create a new WLAN using the VLAN interface created in step 1.

In order to do that, I click on WLANs menu, and Go.

![[2025-11-26_14-35.png]]

I choose a profile name, an SSID and the ID for this WLAN, and apply the configuration.

![[Pasted image 20251126143752.png]]

Now that I created the WLAN, I enable it and assign a Interface/Interface Group(G), which the WLC will use for user traffic on the network. Its the interface I created on Step 1.

![[Pasted image 20251126144014.png]]

4. Configure WLAN security.
Now I will configure the WLAN security using WPA2-Enterprise.
I go to the Layer 2, on the Security tab, where I select WPA+WPA2 from the drop down menu.
I enable WPA2 Policy, with the 802.1X protocol to authenticate users externally.
Then, on the AAA Servers tab, from the dropdown menu I select the RADIUS server I configured on the step 2, and apply the configuration.


![[Pasted image 20251126144446.png]]
![[Pasted image 20251126144516.png]]

---------

### Part 2
Configuring a DHCP Scope and SNMP (Simple Network Management Protocol)

The WLC offers its own internal DHCP server. Although is not recommended for high-volume DHCP services, in smaller networks the DHCP server can be used to provide IP addresses to LAPs (Lightweight Access Ports) that are connected to the wired management network. In this steps I will configure a DHCP scope on the WLC and use it to address LAP-1.

1. From the Controller menu, I click on the Interfaces submenu. There I see the interfaces configured in this WLC. I see the Interface that I created on step 1, the management interface and the virtual interface.

- **Management interface** -> used for WLC GUI, AP join, CAPWAP
- **Dynamic interfaces (like WLAN-5)** -> map WLANs to VLANs
- **Virtual interface** -> internal WLC functions (DHCP proxy, web auth, mobility). **Does not carry users traffic**. It **does not exist on the wired network**. It is **not used as a gateway**.

Management interface details: 
IP address: 192.168.200.254
Net mask: 255.255.255.0
Gateway: 192.168.200.1
Primary DHCP server: 0.0.0.0

![[2025-11-26_14-55.png]]

As I want the WLC to use its own DHCP server to provide addressing to devices on the wireless management network, such as LAPs, I set the WLC itself as the DHCP server for that network. 
When an AP requests DHCP, the WLC (internal DHCP server) will answer.

![[2025-11-26_15-23.png]]

I create a new scope called **Wired Management**
I will define a small range of IP addresses that the WLC can assign to: LAP-1, any other device connected to the management network and potential future APs
This is will be my “management DHCP pool.”


![[2025-11-26_15-25.png]]![[Pasted image 20251126152640.png]]
![[Pasted image 20251126152743.png]]

The network and netmask must match the management interface because this DHCP scope applies to the management VLAN. This scope is used only for management devices like LAPs, not for user traffic.

![[Pasted image 20251126153048.png]]

The DHCP scope has been created an now management devices connected to that VLAN interface will receive a DHCP in this scope.

![[Pasted image 20251126153547.png]]


### Step 2: Configuring SNMP

I will configure the WLC to **send SNMP traps** to an external server so that the network management system can **monitor** the WLC.

To create a new Trap Receiver I go under the Management menu, SNMP submenu and Trap Receivers option. This is where you tell the WLC _where_ to send SNMP notifications. I click then on the New... button.

![[2025-11-26_16-30.png]]

I give this SNMP Trap Receiver a Community Name and IP Address (The WLC will now send SNMP messages to this server IP Address)

![[Pasted image 20251126163425.png]]

I verify that the Trap Receiver has been successfully created.

![[Pasted image 20251126163907.png]]

### Step 3: Configuring a host to connect to the enterprise network

On Packet Tracer I must configure a new profile in order to this host to connect to the network because WPA2-Enterprise requires a **profile**, not a simple “click & connect” like WPA2-PSK. I open the Profiles tab inside PC Wireless option.

![[Pasted image 20251126164233.png]]

I assign a name to this Profile.

![[Pasted image 20251126164352.png]]

I go then to the Advance Setup option

![[Pasted image 20251126164451.png]]

I enter the name of the WLAN to which I want this device to connect. 

![[Pasted image 20251126164558.png]]
![[Pasted image 20251126164939.png]]![[Pasted image 20251126164948.png]]
![[Pasted image 20251126165035.png]]

![[Pasted image 20251127093510.png]]

![[Pasted image 20251126111200.png]]

As I connected to the access point successfully and I received a IP address through DHCP I finish this excercise.

What I learned:

- I can configure the WLC to **send SNMP traps** to an external server so that the network management system can **monitor** the WLC. In Management -> SNMP -> Trap Receivers.
- Using a RADIUS server is preferred in larger setups as scalates better and its more secure.
- How the WLC internal DHCP works and how to configure a pool.