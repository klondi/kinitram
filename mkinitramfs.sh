#!/bin/bash

function findlibs {
  for j in $*; do
      if [ -e "$j" ]; then echo "$j";
      elif [ -e "/lib64/$j" ]; then echo "/lib64/$j"; 
      elif [ -e "/usr/lib64/$j" ]; then echo "/usr/lib64/$j"; 
      fi;
    for i in $(ldd "$j" | cut '-d ' -f1); do
      if [ -e "$i" ]; then echo "$i";
      elif [ -e "/lib64/$i" ]; then echo "/lib64/$i";
      elif [ -e "/usr/lib64/$i" ]; then echo "/usr/lib64/$i";
      fi;
    done;
  done | sort | uniq
}

function getlibs {
  old=$*;
  new = $(findlibs $old);
  while [ "$old" != "$new" ]; do
    old = "$new";
    new = $(findlibs $old);
  done;
  echo $new;
}

#hook
function after_copy {
ln -s busybox bin/bb
}

elf_files="/sbin/mdadm
/sbin/lvm
/sbin/btrfs
/sbin/cryptsetup
/bin/busybox
/usr/sbin/dropbear
/lib64/libnss_compat.so.2
/lib64/libnss_files.so.2
/lib64/libnss_dns.so.2"

files="$(findlibs $elf_files)
/etc/localtime
/etc/gai.conf
/etc/resolv.conf
/etc/host.conf
/etc/mdadm.conf
"

#Create the dropbear keys if necessary
[ -e /usr/src/initram/initramfs/etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f  /usr/src/initram/initramfs/etc/dropbear/dropbear_dss_host_key
[ -e /usr/src/initram/initramfs/etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f  /usr/src/initram/initramfs/etc/dropbear/dropbear_rsa_host_key -s 4096

rm -r /usr/src/initram/initramfs.tmp
cp /usr/src/initram/initramfs /usr/src/initram/initramfs.tmp -aR
chown -R root:root /usr/src/initram/initramfs.tmp

cd /usr/src/initram/initramfs.tmp && (
for i in $files; do mkdir -p `dirname ${i:1}`; cp -L $i ${i:1}; done
after_copy
find . -print0 | cpio -ov -0 --format=newc > /boot/my-initramfs.cpio
gzip -9 < /boot/my-initramfs.cpio > /boot/my-initramfs.cpio.gz &
xz -9 --check=crc32 -c < /boot/my-initramfs.cpio > /boot/my-initramfs.cpio.xz

wait

find kernel -print0 | cpio -ov0 --format=newc | cat - /boot/my-initramfs.cpio.gz > /boot/my-initramfs-mc.cpio.gz
find kernel -print0 | cpio -ov0 --format=newc | cat - /boot/my-initramfs.cpio.xz > /boot/my-initramfs-mc.cpio.xz
find kernel -print0 | cpio -ov0 --format=newc | cat - /boot/my-initramfs.cpio > /boot/my-initramfs-mc.cpio
rm -r kernel
)
