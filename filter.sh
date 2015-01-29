#!/bin/sh
	
# drop all outbound packets
iptables -P OUTPUT DROP

# allow outbound dns client queries
iptables -A OUTPUT -p udp -o eth0 --dport 53 -j ACCEPT
iptables -A INPUT -p udp -i eth0 --sport 53 -j ACCEPT

# allow outbound tcp only for port 1080 (pia socks5 proxy)
iptables -A OUTPUT -p tcp -o eth0 --dport 1080 -j ACCEPT
iptables -A INPUT -p tcp -i eth0 --sport 1080 -j ACCEPT

# allow outbound udp only for port 1080 (pia socks5 proxy)
iptables -A OUTPUT -p udp -o eth0 --dport 1080 -j ACCEPT
iptables -A INPUT -p udp -i eth0 --sport 1080 -j ACCEPT