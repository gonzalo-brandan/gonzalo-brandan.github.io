
![[Pasted image 20251204203550.png]]
✔ Simple example

#ACL:

deny   ip host 10.1.1.5 any
permit ip any any


Meaning:

Block 10.1.1.5 from talking to anyone

Allow everyone else

But if you wrote:

permit ip any any
deny ip host 10.1.1.5 any

The second deny line never executes because the first line already allows everything.

✅ Order of elements in an extended ACL entry

Extended ACLs always follow this structure, from left to right:

access-list number
action (permit/deny)
protocol (tcp/udp/ip/icmp etc.)
**source IP**
source wildcard mask
**destination IP**
destination wildcard mask
optional matching conditions
(such as eq, lt, gt, range, port number, etc.)

`eq` tells the router:
Match traffic where the destination (or sometimes source) port **equals** a specific port.
eq www     (same as eq 80)
eq https   (same as eq 443)
eq ssh     (same as eq 22)
eq dns     (same as eq 53)