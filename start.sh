#!/bin/sh

#run deluge daemon (non daemonized)
/usr/bin/deluged -d -c /config -L info -l /config/deluged.log

#run deluge webui
/usr/bin/deluge-web -c /config