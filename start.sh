#!/bin/sh

# filter outbound traffic depending on env variable defined
if [[ $FILTER > 0 ]]; then
	echo "Filtering outbound communioation"
	
	# drop all outbound packets
	iptables -P OUTPUT DROP

	# allow outbound dns client queries
	iptables -A OUTPUT -p udp -o eth0 --dport 53 -j ACCEPT
	iptables -A INPUT -p udp -i eth0 --sport 53 -j ACCEPT

	# allow outbound tcp only for port 1080 (pia socks5 proxy)
	iptables -A OUTPUT -p tcp -o eth0 --dport $FILTER -j ACCEPT
	iptables -A INPUT -p tcp -i eth0 --sport $FILTER -j ACCEPT
	
	# allow outbound udp only for port 1080 (pia socks5 proxy)
	iptables -A OUTPUT -p udp -o eth0 --dport $FILTER -j ACCEPT
	iptables -A INPUT -p udp -i eth0 --sport $FILTER -j ACCEPT
		
elif [[ $FILTER == 0 ]]; then
	echo "Outbound communication not filtered"
	
else
	echo "Outbound communication not defined, defaulting to not filtered"
		
fi
