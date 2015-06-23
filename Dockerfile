FROM binhex/arch-base:2015062300
MAINTAINER binhex

# additional files
##################

# add supervisor conf file for app
ADD *.conf /etc/supervisor/conf.d/

# add install bash script
ADD install.sh /root/

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/install.sh && \
	/bin/bash /root/install.sh

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

# set environment variables for user nobody
ENV HOME /home/nobody

# run supervisor
################

# run supervisor
CMD ["supervisord", "-c", "/etc/supervisor.conf", "-n"]