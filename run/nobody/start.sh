#!/usr/bin/dumb-init /bin/bash

function common(){

	# source in script to wait for child processes to exit
	source waitproc.sh

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

	if [[ -z "${WEBUI_PORT}" ]]; then
		echo "[info] Environment variable 'WEBUI_PORT' is not set, defaulting to 8112..."
		WEBUI_PORT=8112
	else
		echo "[info] Using WEBUI_PORT=${WEBUI_PORT}"
	fi

	echo "[info] Starting Deluge Web UI..."
	portset.sh --application-name 'deluge' --webui-port "${WEBUI_PORT}" --application-parameters /usr/bin/deluge-web --do-not-daemonize --port "${WEBUI_PORT}" --config /config --loglevel "${DELUGE_WEB_LOG_LEVEL}" --logfile /config/deluge-web.log
}

main