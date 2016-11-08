#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curl -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
find /tmp/scripts-master/ -type f -name '*.sh' -exec mv -i {} /root/  \;

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
aor_packages=""

# call aor script (arch official repo)
source /root/aor.sh

# manually download stable package from binhex repo (latest deluge on aor is beta/rc)
curl -o /tmp/deluge-1.3.11-3-any.pkg.tar.xz -L https://github.com/binhex/arch-packages/raw/master/compiled/deluge-1.3.13-1-any.pkg.tar.xz
pacman -U /tmp/deluge-1.3.11-3-any.pkg.tar.xz --noconfirm

# aur packages
####

# define aur helper
aur_helper="apacman"

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source /root/aur.sh

# container perms
####

# create file with contets of here doc
cat <<'EOF' > /tmp/permissions_heredoc
# set permissions inside container
chown -R "${PUID}":"${PGID}" /usr/bin/deluged /usr/bin/deluge-web /home/nobody
chmod -R 775 /usr/bin/deluged /usr/bin/deluge-web /home/nobody

# set python.eggs folder to rx only for group and others
mkdir -p /home/nobody/.python-eggs && chmod -R 755 /home/nobody/.python-eggs

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
