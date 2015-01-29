#!/bin/sh

# enable/disable pia proxy only based on env variable set from docker container run command
if [[ $PIAPROXY == "yes" ]]; then
	echo "Restricting outbound communioation to PIA proxy only"
	
	# drop all outbound packets
	iptables -P OUTPUT DROP

	# allow outbound dns client queries
	iptables -A OUTPUT -p udp -o eth0 --dport 53 -j ACCEPT
	iptables -A INPUT -p udp -i eth0 --sport 53 -j ACCEPT

	# allow outbound socks proxy only to pia (tcp)
	iptables -A OUTPUT -o eth0 -p tcp -d proxy-nl.privateinternetaccess.com --dport 1080 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A INPUT -i eth0 -p tcp --sport 1080 -m state --state ESTABLISHED -j ACCEPT

	# allow outbound socks proxy only to pia (udp)
	iptables -A OUTPUT -o eth0 -p udp -d proxy-nl.privateinternetaccess.com --dport 1080 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A INPUT -i eth0 -p udp --sport 1080 -m state --state ESTABLISHED -j ACCEPT
		
elif [[ $PIAPROXY == "no" ]]; then
	echo "Outbound communication unrestricted"
	
else
	echo "Outbound communication not defined, defaulting to unrestricted"
		
fi