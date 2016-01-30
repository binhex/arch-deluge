**Application**

[Deluge](http://deluge-torrent.org/)

**Application description**

Deluge is a full-featured ​BitTorrent client for Linux, OS X, Unix and Windows. It uses ​libtorrent in its backend and features multiple user-interfaces including: GTK+, web and console. It has been designed using the client server model with a daemon process that handles all the bittorrent activity. The Deluge daemon is able to run on headless machines with the user-interfaces being able to connect remotely from any platform.

**Build notes**

Latest stable Deluge release from Arch Linux repo.

**Usage**
```
docker run -d \
	-p 8112:8112 \
	-p 58846:58846 \
	-p 58946:58946 \
	--name=<container name> \
	-v <path for data files>:/data \
	-v <path for config files>:/config \
	-v /etc/localtime:/etc/localtime:ro \
	binhex/arch-deluge
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access application**<br>

`http://<host ip>:8112`

**Example**
```
docker run -d \
	-p 8112:8112 \
	-p 58846:58846 \
	-p 58946:58946 \
	--name=deluge \
	-v /apps/docker/deluge/data:/data \
	-v /apps/docker/deluge/config:/config \
	-v /etc/localtime:/etc/localtime:ro \
	binhex/arch-deluge
```

**Notes**<br>

Default password for the webui is "deluge"

[Support forum](http://lime-technology.com/forum/index.php?topic=45820.0)