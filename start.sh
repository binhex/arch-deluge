#!/bin/sh

# restore iptable rules on startup
iptables-restore < /etc/iptables/iptables.rules