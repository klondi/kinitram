#!/bin/bash

mypath="$(realpath "$( dirname $0 )" )"

function fail {
  echo $@;
  exit 1;
}

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
ln -s busybox bin/bb || fail Link busybox
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
[ -e "$mypath/initramfs/etc/dropbear/dropbear_rsa_host_key" ] || dropbearkey -t rsa -f  "$mypath/initramfs/etc/dropbear/dropbear_rsa_host_key" -s 4096 || fail Create dropbear keys
[ -e "$mypath/initramfs/etc/dropbear/dropbear_ecdsa_host_key" ] || dropbearkey -t ecdsa -f  "$mypath/initramfs/etc/dropbear/dropbear_ecdsa_host_key" -s 256 || fail Create dropbear keys

rm -rf "$mypath/initramfs.tmp"  || fail Cleanup
cp "$mypath/initramfs" "$mypath/initramfs.tmp" -aR  || fail Create initial components

unset CPIO
[ -z "$CPIO" ] && cpio > /dev/null 2> /dev/null
[ -z "$CPIO" -a $? -eq 2 ] && export CPIO=cpio
[ -z "$CPIO" ] && busybox  cpio > /dev/null 2> /dev/null
[ -z "$CPIO" -a $? -eq 1 ] && export CPIO="busybox cpio"
[ -n "$CPIO" ] || fail Find cpio

cd "$mypath"/initramfs.tmp && (
for i in $files; do mkdir -p "$(dirname ${i:1})" || fail Create dir; cp -L $i ${i:1} || fail Copy file; done
after_copy
find . -not -name .keep -print0 | $CPIO -H +0:+0 -o -0 --format=newc | tee ../my-initramfs.cpio | lz4 -16 -c > /boot/my-initramfs.cpio.lz4 || fail Create initram
) || fail cd into tmpfile
rm -rf "$mypath/initramfs.tmp"
