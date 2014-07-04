deluge
======

Latest stable Deluge release for Arch Linux.

This is a Dockerfile for Deluge - http://deluge-torrent.org/

**Pull image**

```
docker pull binhex/arch-deluge
```

**Run container**

```
docker run -d -p 8112:8112 -p 8122:8122 -p 53160:53160 -p 58846:58846 --name=<container name> -v <path for data files>:/data -v <path for config files>:/config -v /etc/localtime:/etc/localtime:ro binhex/arch-deluge
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access application**

```
http://<host ip>:8112
```

or for SSL

```
https://<host ip>:8122
```
