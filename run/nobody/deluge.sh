#!/bin/bash

# if config file doesnt exist (wont exist until user changes a setting) then copy default config file
if [[ ! -f /config/core.conf ]]; then

	echo "[info] Deluge config file doesn't exist, copying default..."
	cp /home/nobody/deluge/core.conf /config/

else

	echo "[info] Deluge config file already exists, skipping copy"

fi

# run deluge daemon (daemonized, non-blocking)
echo "[info] Attempting to start Deluge..."
/usr/bin/deluged -c /config -L info -l /config/deluged.log

# run script to check we don't have any torrents in an error state
/home/nobody/torrentcheck.sh

# run cat to prevent script exit
cat
