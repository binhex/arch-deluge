FROM binhex/arch-base:2014091500
MAINTAINER binhex

# install application
#####################

# update package databases for arch
RUN pacman -Sy --noconfirm

# run pacman to install application
RUN pacman -S unzip unrar deluge python2-service-identity python2-mako python2-notify --noconfirm

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

# set permissions
#################

# change owner
RUN chown nobody:users /usr/bin/deluged /usr/bin/deluge-web /root

# set permissions
RUN chmod 775 /usr/bin/deluged /usr/bin/deluge-web /root

# add conf file
###############

ADD deluge.conf /etc/supervisor/conf.d/deluge.conf

# cleanup
#########

# remove uneeded apps from base-devel group - used for AUR package compilation
RUN pacman -Ru base-devel --noconfirm

# completely empty pacman cache folder
RUN pacman -Scc --noconfirm

# remove temporary files
RUN rm -rf /tmp/*

# run supervisor
################

# run supervisor
CMD ["supervisord", "-c", "/etc/supervisor.conf", "-n"]
