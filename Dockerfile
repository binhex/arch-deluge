FROM binhex/arch-base:2014101300
MAINTAINER binhex

# additional files
##################

# add supervisor conf file for app
ADD deluge.conf /etc/supervisor/conf.d/deluge.conf

# copy start bash script (starts deluge daemon and webui in the correct order)
ADD start.sh /usr/bin/start.sh

# install app
#############

# install install app using pacman, set perms, cleanup
RUN pacman -Sy --noconfirm && \
	pacman -S unzip unrar deluge python2-service-identity python2-mako python2-notify --noconfirm && \
	pacman -Scc --noconfirm && \
	chown -R nobody:users /usr/bin/start.sh /usr/bin/deluged /usr/bin/deluge-web /root && \
	chmod -R 775 /usr/bin/start.sh /usr/bin/deluged /usr/bin/deluge-web /root && \	
	rm -rf /archlinux/usr/share/locale && \
	rm -rf /archlinux/usr/share/man && \
	rm -rf /root/* && \
	rm -rf /tmp/*

# docker settings
#################

# map /config to host defined config path (used to store configuration from app)
VOLUME /config

# map /data to host defined data path (used to store data from app)
VOLUME /data

# expose port for http
EXPOSE 8112

# expose port for deluge daemon
EXPOSE 58846

# expose port for incoming torrent data (tcp and udp)
EXPOSE 58946
EXPOSE 58946/udp

# run supervisor
################

# run supervisor
CMD ["supervisord", "-c", "/etc/supervisor.conf", "-n"]