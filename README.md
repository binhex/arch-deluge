Deluge
======

Deluge - http://deluge-torrent.org/

Latest stable Deluge release for Arch Linux.

**Pull image**

```
docker pull binhex/arch-deluge
```

**Run container**

```
docker run -d -p 8112:8112 -p 58846:58846 -p 58946:58946 --name=<container name> -e PIAPROXY="no" -v <path for data files>:/data -v <path for config files>:/config -v /etc/localtime:/etc/localtime:ro binhex/arch-deluge
```

Please replace all user variables in the above command defined by <> with the correct values.

Note:- If you wish to restrict outbound traffic only to PIA proxy then please set the environment variable (PIAPROXY="no") to "yes", otherwise set to "no" to allow any outbound traffic.

**Access application**

```
http://<host ip>:8112
```

Default password for the webui is "deluge"
