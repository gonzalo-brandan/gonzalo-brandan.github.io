---
topic: Wireless
title: "Setting up a password-protected Wi-Fi network on a Cisco controller"
date: 2025-11-29 16:00:00 +0000
categories: networking
tags: [WLAN, Cisco, Tutorial]
comments: true
toc: true
layout: post
image:
  path: "/assets/img/Pasted image 20251125144231.png"
  alt: "WLAN lab topology"
---
In a company, you don't configure each access point one by one. A wireless LAN controller (WLC) manages all of them from one place. In this lab I create a new Wi-Fi network on the controller, protect it with a password, and connect a laptop to it.

### Topology

![description](/assets/img/Pasted image 20251125144445.png)

### 1. Log in to the controller

From the Admin PC I open a browser and go to the WLC's management IP. It has to be `https://`: the controller only accepts secure sessions.

![description](/assets/img/Pasted image 20251125145344.png)

The first screen is the Monitor Summary:
![description](/assets/img/Pasted image 20251125145624.png)

It shows how many access points have joined, how many clients are connected and which WLANs are on. The first thing I look for is an AP that has joined. Without one, no device can connect to anything.

Here one AP has joined and it's up. There are no clients yet.
![description](/assets/img/Pasted image 20251125150217.png)

"Detail" next to All APs shows more about each one.

### 2. Create the WLAN

Under **WLANs**, I choose **Create New**.

![description](/assets/img/2025-11-25_16-44.png)

A WLAN needs three names:

- **Profile name**: the label admins see in the controller.
- **SSID**: the network name people see on their phone or laptop.
- **ID**: the number the controller uses internally, for example in logs.

I click Apply.

![description](/assets/img/Pasted image 20251125164808.png)

The WLAN exists now, but it's off, so I tick **Enabled**. I also pick the interface. This matters: it tells the controller which VLAN and subnet the clients go into. Here that's the WLAN-5 interface I set up earlier.

![description](/assets/img/2025-11-25_16-56.png)

In the **Advanced** tab I turn on two FlexConnect options:

- **Local Switching**: the AP sends client traffic straight into the local VLAN, instead of sending it all back to the controller first.
- **Local Auth**: the AP checks clients itself, so people can still connect if the link to the controller goes down.

![description](/assets/img/2025-11-25_17-02.png)

The new WLAN, "Floor 2 Employees", shows up in the list.

![description](/assets/img/2025-11-25_17-13.png)

### 3. Add a password

Right now the network is open to anyone. I protect it with **WPA2-PSK**: one shared password for everyone.

In the WLAN's **Security → Layer 2** tab, I choose WPA+WPA2, enable PSK and set the key to `Cisco123`. (A real network would use a much longer one.)

![description](/assets/img/2025-11-25_17-25.png)
![description](/assets/img/Pasted image 20251125173402.png)

A shared password is fine for a small office, but not for a company: everyone has the same key, and changing it means telling everyone. In the next post I replace it with WPA2-Enterprise, where each person logs in with their own account through a RADIUS server.

The security settings are now in place:

![description](/assets/img/Pasted image 20251125173633.png)

### 4. Connect a laptop

![description](/assets/img/Screenshot from 2025-11-26 11-10-46.png)

![description](/assets/img/Screenshot from 2025-11-26 11-11-03.png)

I pick the network and type the password, `Cisco123`.

![description](/assets/img/Pasted image 20251126111200.png)

It connects, and the laptop gets an IP address from DHCP.

![description](/assets/img/Pasted image 20251126111509.png)

Last check: a ping to the server. It answers, so the whole path works, from the laptop through the AP to the rest of the network.

![description](/assets/img/Pasted image 20251126111723.png)
