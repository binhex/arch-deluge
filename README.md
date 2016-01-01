**Deluge**<br>
[Application website](http://deluge-torrent.org/)

**Description**<br>
Latest stable release of Deluge using Pacman to install.

**Usage**
```
docker run -d 
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

**Notes**<br>
Default password for the webui is "deluge"

[Support forum](http://lime-technology.com/forum/index.php?topic=38055.0)