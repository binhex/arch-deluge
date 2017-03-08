#!/bin/bash

# exit script if return code != 0
set -e

# required due to the fact that libtorrent 1.1.x is not compatible with deluge 1.3.x (hopefully fixed in deluge 2.x)
pkg_name="libtorrent-rasterbar"
pkg_ver="1-1.0.9-1-x86_64"

# download compiled package(s) from binhex repo
curl -o "/tmp/${pkg_name}-${pkg_ver}.pkg.tar.xz" -L "https://github.com/binhex/arch-packages/raw/master/compiled/${pkg_name}-${pkg_ver}.pkg.tar.xz"
pacman -U "/tmp/${pkg_name}-${pkg_ver}.pkg.tar.xz" --noconfirm
