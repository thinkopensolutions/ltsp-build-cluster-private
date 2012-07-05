#!/bin/bash

# LTSP Load Balancer
# 172.31.100.12

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

apt-get -y install ltsp-cluster-lbserver  || fail "Installing ltsp-cluster-lbserver"

echo "172.31.100.13 ltsp-appserv01.primeschool.pt ltsp-appserv01" >> /etc/hosts || fail "Adding appserv to hosts"

# Configure lbs
sed -i "s/yourdomain.com/primeschool.pt/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"
sed -i "s/max-threads=\"2\"/max-threads=\"1\"/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"
sed -i "s/<group default=\"true\" name=\"default\">/<group default=\"true\" name=\"precise\">/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"

/etc/init.d/ltsp-cluster-lbserver restart || fail "restarting lbs server"

echo "OK ENTER FOR REBOOT"
read x
reboot
