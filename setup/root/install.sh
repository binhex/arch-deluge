#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
find /tmp/scripts-master/ -type f -name '*.sh' -exec mv -i {} /root/  \;

# custom scripts
####

# call custom install script
source /root/custom.sh

# pacman packages
####

# define pacman packages
pacman_packages="pygtk python2-service-identity python2-mako python2-notify"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aor packages
####

# define arch official repo (aor) packages
aor_packages="deluge"

# call aor script (arch official repo)
source /root/aor.sh

# aur packages
####

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source /root/aur.sh

# container perms
####

# create file with contets of here doc
cat <<'EOF' > /tmp/permissions_heredoc
echo "[info] Setting permissions on files/folders inside container..." | ts '%Y-%m-%d %H:%M:%.S'

# create path to store deluge python eggs
mkdir -p /home/nobody/.cache/Python-Eggs

chown -R "${PUID}":"${PGID}" /usr/bin/deluged /usr/bin/deluge-web /home/nobody
chmod -R 775 /usr/bin/deluged /usr/bin/deluge-web /home/nobody

# remove permissions for group and other from the Python-Eggs folder
chmod -R 700 /home/nobody/.cache/Python-Eggs

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /root/init.sh
rm /tmp/permissions_heredoc

# env vars
####

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /tmp/*
