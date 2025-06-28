#!/usr/bin/dumb-init /bin/bash

function start_deluge() {

	# running common setup tasks
	common

	echo "[info] Deluge process listening on port 58846"

	if ! pgrep -x "deluge-web" > /dev/null; then
		echo "[info] Starting Deluge Web UI..."

		# run process non daemonised (blocking)
		/usr/bin/deluge-web -d -c /config -L "${DELUGE_WEB_LOG_LEVEL}" -l /config/deluge-web.log
	fi
}

function common(){

	# source in script to wait for child processes to exit
	source /usr/local/bin/waitproc.sh

	# set location for python eggs
	python_egg_cache="/config/python-eggs"

	if [[ ! -d "${python_egg_cache}" ]]; then
		echo "[info] Creating Deluge Python Egg cache folder..."
		mkdir -p "${python_egg_cache}"
		chmod -R 755 "${python_egg_cache}"
	fi

	# export location of python egg cache
	export PYTHON_EGG_CACHE="${python_egg_cache}"

	echo "[info] Attempting to start Deluge..."

	echo "[info] Removing deluge pid file (if it exists)..."
	rm -f /config/deluged.pid

	# run process non daemonised but backgrounded so we can control sigterm
	nohup /usr/bin/deluged -d -c /config -L "${DELUGE_DAEMON_LOG_LEVEL}" -l /config/deluged.log &
	echo "[info] Deluge process started"

	echo "[info] Waiting for Deluge daemon process to start listening on port 58846..."
	while [[ $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".58846\"") == "" ]]; do
		sleep 0.1
	done
	echo "[info] Deluge process listening on port 58846"
}

function main() {

	# running common setup tasks
	common

	if [[ "${CONFIGURE_INCOMING_PORT}" == "yes" ]]; then

		echo "[info] Starting Deluge Web UI with port configuration..."
		/usr/local/bin/portget.sh --application-name "${APPLICATION_NAME}" --application-port "${APPLICATION_PORT}" /usr/bin/deluge-web -d -c /config -L "${DELUGE_WEB_LOG_LEVEL}" -l /config/deluge-web.log
	else
		echo "[info] Skipping port configuration as env var 'CONFIGURE_INCOMING_PORT' is not set to 'yes'"
		start_deluge
	fi
}

main