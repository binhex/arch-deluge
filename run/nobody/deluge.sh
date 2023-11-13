#!/usr/bin/dumb-init /bin/bash

# source in script to wait for child processes to exit
source /usr/local/bin/waitproc.sh

# if config file doesnt exist (wont exist until user changes a setting) then copy default config file
if [[ ! -f /config/core.conf ]]; then

	echo "[info] Deluge config file doesn't exist, copying default..."
	cp /home/nobody/deluge/core.conf /config/

else

	echo "[info] Deluge config file already exists, skipping copy"

fi

echo "[info] Attempting to start Deluge..."

echo "[info] Removing deluge pid file (if it exists)..."
rm -f /config/deluged.pid

# run process non daemonised but backgrounded so we can control sigterm
nohup /usr/bin/deluged -d -c /config -L "${DELUGE_DAEMON_LOG_LEVEL}" -l /config/deluged.log &
echo "[info] Deluge process started"

echo "[info] Waiting for Deluge process to start listening on port 58846..."
while [[ $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".58846\"") == "" ]]; do
	sleep 0.1
done

echo "[info] Deluge process listening on port 58846"

# run script to check we don't have any torrents in an error state
/home/nobody/torrentcheck.sh

if ! pgrep -x "deluge-web" > /dev/null; then
	echo "[info] Starting Deluge Web UI..."

	# run process non daemonised (blocking)
	/usr/bin/deluge-web -d -c /config -L "${DELUGE_WEB_LOG_LEVEL}" -l /config/deluge-web.log
fi
