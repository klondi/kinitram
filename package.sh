#!/bin/sh
tar -c --exclude='.keep' --exclude=authorized_keys --exclude="dropbear_*_host_key" --owner=0 --group=0 --numeric-owner --mtime="$(date +@%s)" initramfs/ mkinitramfs.sh | xz -9e > kinitram.tar.xz
