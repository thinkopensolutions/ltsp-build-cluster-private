#!/bin/bash

# NFS Server

. ltsp-include.sh

# Instalação de aplicações
apt-get -y update || fail "Updating repository"
apt-get -y dist-upgrade || fail "Dist-upgrading"

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

