#!/bin/bash

#run deluge daemon
exec /usr/bin/deluged -d -c /config -L info -l /config/deluged.log

#run deluge webui
exec /usr/bin/deluge-web -c /config