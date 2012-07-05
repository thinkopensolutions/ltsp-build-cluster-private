#!/bin/bash

# NFS Server
# 172.31.100.27-...

function fail() {
    echo "[FAIL $1]"
    exit -1
}

# SSH
if ! [ -s ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa || fail "Generating ssh key"
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA9xJsdD3E0T6KvjYd/+gF2+lnUWkRyRBx3QcgcVUnj1MkLe8wC1IXQ4bE5VUs/ESj64mLejFVtqxdYheK2r/1im1ZuX7ObkXEQKMjAbqN451jxGeWLyvhfCVRu/7KPl//I8uJ3uQCukYSN8YAJKKDRl6rbLklhsK7pi31MYsZawvl1xZaztjzzT1E3fdSUfRyTJM+MxZ8RBSQLQXMwip4SvagIQLS+CTIhWxo5pWoXYynuksHtQEaWmPB8nDAApVguHLCL1oZNdzQ9ZRuHirsaBQV6bOxxPhJouGcZbfVGWdhrGVAjd8IwYbuydoeWe6yqTYNiYTfkoYxuOrbYGBbiQ== root@primeschool" > .ssh/authorized_keys || fail "Importing ssh key"
fi

if ! [ "$LANG" == "pt_PT.UTF-8" -o $(grep pt_PT.UTF-8 /etc/default/locale | wc -l) -eq 1 ]; then
    locale-gen en_US.UTF-8 || fail "Generating locale en_US.UTF-8"
    locale-gen pt_PT.UTF-8 || fail "Generating locale pt_PT.UTF-8"
    dpkg-reconfigure locales || fail "Configuring locales"
    dpkg-reconfigure tzdata || fail "Configuring tzdata"
    update-locale LANG=pt_PT.UTF-8 LANGUAGE || fail "Setting LANG"
fi

# Instalação de aplicações
apt-get -y update || fail "Updating repository"
apt-get -y dist-upgrade || fail "Dist-upgrading"

apt-get -y install nfs-kernel-server
if ! [ $(cat /etc/exports | grep "# LTSP Home mount point" | wc -l) -gt 0 ]; then
    echo "/home    *(rw,sync,no_root_squash,no_subtree_check) # LTSP Home mount point" >> /etc/exports
fi

if ! [ $(cat /etc/rc.local | grep "start portmap" | wc -l) -gt 0 ]; then
    sed -i "s/^exit 0$/start portmap\n\nexit 0/g" /etc/rc.local || fail "SEDing rc.local"
fi

if ! [ $(cat /etc/rc.local | grep "nfs-kernel-server" | wc -l) -gt 0 ]; then
    sed -i "s/^exit 0$/\/etc\/init.d\/nfs-kernel-server start\n\nexit 0/g" /etc/rc.local || fail "SEDing rc.local"
fi

echo "OK ENTER FOR REBOOT"
read x
reboot

