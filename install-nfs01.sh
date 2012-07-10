#!/bin/bash

# NFS Server

echo "### README FIRST ###
This is to do on PROXMOX node server where the VM will run.
To be able to run nfs-kernel-server the following modules must be running in PROXMOX node server:
    modprobe nfs
    modprobe nfsd
    (should add them to /etc/modules)
Validate if it is running on node:
    proxmox01:~# cat /proc/filesystems | grep nfsd
    (must has nfsd)
Add this lines to /etc/sysctl.d/vzctl.conf:
    sunrpc.ve_allow_rpc = 1
    fs.nfs.ve_allow_nfs = 1
    kernel.ve_allow_kthreads = 1
After that run:
    proxmox01:~# sysctl -p
Stop NFS server VM and run (note nfsd):
    proxmox01:~# vzctl set VMID --features \"nfsd:on\" --save
Stop all application servers and run (note nfs):
    proxmox01:~# vzctl set VMID --features \"nfs:on\" --save
(PRESS ENTER TO INSTALL NFS SERVER OR CTRL+C TO CANCEL)"
read x

. ltsp-include.sh

apt-get -y install nfs-kernel-server || fail "Installing nfs-kernel-server"

if ! [ $(cat /etc/exports | grep "# LTSP Home mount point" | wc -l) -gt 0 ]; then
    echo "/home    *(rw,sync,no_root_squash,no_subtree_check) # LTSP Home mount point" >> /etc/exports || fail "Adding to exports"
fi

if ! [ $(cat /etc/rc.local | grep "start portmap" | wc -l) -gt 0 ]; then
    sed -i "s/^exit 0$/start portmap\n\nexit 0/g" /etc/rc.local || fail "SEDing rc.local"
    start portmap
fi

if ! [ $(cat /etc/rc.local | grep "nfs-kernel-server" | wc -l) -gt 0 ]; then
    sed -i "s/^exit 0$/\/etc\/init.d\/nfs-kernel-server start\n\nexit 0/g" /etc/rc.local || fail "SEDing rc.local"
    /etc/init.d/nfs-kernel-server start
fi

echo "OK ENTER FOR REBOOT"; read x; reboot

