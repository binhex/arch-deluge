#!/usr/bin/dumb-init /bin/bash

# source in script to wait for child processes to exit
source waitproc.sh

function geoip() {

  local geoip_dat_path
  local geoip_url

  geoip_dat_path="/config/GeoIP.dat"
  geoip_url="https://geo.el0.org/GeoIP.dat.gz"

  echo "[info] Checking GeoIP.dat ${geoip_dat_path}..."

  if [[ -f "${geoip_dat_path}" ]]; then

    local current_time
    current_time=$(date +%s)

    local modification_time
    local week_seconds

    modification_time=$(stat -c %Y "${geoip_dat_path}")
    week_seconds=$(( 7 * 24 * 60 * 60 ))

    if (( (current_time - modification_time) > week_seconds )); then
      echo "[info] Found outdated GeoIP.dat...updating (timeout 10s)"
    else
      echo "[info] GeoIP.dat is up to date (downloaded in the last week)"
      return
    fi

  else
    echo "[info] No GeoIP.dat found...updating (timeout 10s)"
  fi

  # download geoip.dat
  rcurl.sh "${geoip_url}" | gunzip > "${geoip_dat_path}" && chmod 777 "${geoip_dat_path}"

  # symlink geoip
  source utils.sh && symlink --src-path "${geoip_dat_path}" --dst-path '/usr/share/GeoIP/GeoIP.dat' --link-type 'softlink'

}

function python_eggs(){

	# set location for python egg cache
  local python_egg_cache
	python_egg_cache="/config/python-eggs"

	if [[ ! -d "${python_egg_cache}" ]]; then
		echo "[info] Creating Deluge Python Egg cache folder..."
		mkdir -p "${python_egg_cache}"
		chmod -R 755 "${python_egg_cache}"
	fi

	# export location of python egg cache
	export PYTHON_EGG_CACHE="${python_egg_cache}"

	# set location for python egg plugins
  local python_egg_plugins
	python_egg_plugins="/config/plugins"

	if [[ ! -d "${python_egg_plugins}" ]]; then
		echo "[info] Creating Deluge Python Egg plugins folder..."
		mkdir -p "${python_egg_plugins}"
		chmod -R 755 "${python_egg_plugins}"
	fi

	# copy itconfig plugin egg file (downloaded in install.sh)
	cp /home/nobody/*.egg "${python_egg_plugins}/"

}

function deluged(){

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

	# download geoip
	geoip

	# set python eggs path
	python_eggs

  # run deluge daemon
	deluged

	if [[ -z "${WEBUI_PORT}" ]]; then
		echo "[info] Environment variable 'WEBUI_PORT' is not set, defaulting to 8112..."
		WEBUI_PORT=8112
	else
		echo "[info] Using WEBUI_PORT=${WEBUI_PORT}"
	fi

	echo "[info] Starting ${APPNAME} Web UI..."
	portset.sh \
		--app-name "${APPNAME}" \
		--webui-port "${WEBUI_PORT}" \
		--gluetun-incoming-port "${GLUETUN_INCOMING_PORT}" \
		--gluetun-control-server-port "${GLUETUN_CONTROL_SERVER_PORT}" \
		--gluetun-control-server-username "${GLUETUN_CONTROL_SERVER_USERNAME}" \
		--gluetun-control-server-password "${GLUETUN_CONTROL_SERVER_PASSWORD}" \
		--app-parameters /usr/bin/deluge-web \
		--do-not-daemonize \
		--port "${WEBUI_PORT}" \
		--config /config \
		--loglevel "${DELUGE_WEB_LOG_LEVEL}" \
		--logfile '/config/deluge-web.log'

}

main