FROM binhex/arch-base:test
MAINTAINER binhex

# install app
#############

# install install app using pacman, set perms, cleanup
RUN pacman -Sy --noconfirm && \
	pacman -S unzip unrar deluge python2-service-identity python2-mako python2-notify --noconfirm && \
	pacman -Scc --noconfirm && \
	chown -R nobody:users /usr/bin/deluged /usr/bin/deluge-web /root && \
	chmod -R 775 /usr/bin/deluged /usr/bin/deluge-web /root && \	
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

# runit scripts
###############

# add deluge to runit
RUN mkdir /etc/service/deluge
ADD runit.sh /etc/service/deluge/run
RUN chmod +x /etc/service/deluge/run

# run services
##############

CMD ["runsvdir", "/etc/service/"]