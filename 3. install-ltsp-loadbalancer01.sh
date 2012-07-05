#!/bin/bash

# LTSP Load Balancer
# 172.31.100.15

# SSH
ssh-keygen -t dsa
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAswXDqk2+azGCQuqNRc/faBhGv0WcCP6gNXYt0nhGgOJ3zsP605+sk02Tz3sybJ3RRIylvMdelzOBbY/m5tSt2A5t+6VWWcEJqnroVJJcx24V/pmW7jpAsj68RxwxALU9NhB0vqB7EBoiEaSevH3yCYcqWVmrkNZU7RS4olfwICk= cmsa
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA9xJsdD3E0T6KvjYd/+gF2+lnUWkRyRBx3QcgcVUnj1MkLe8wC1IXQ4bE5VUs/ESj64mLejFVtqxdYheK2r/1im1ZuX7ObkXEQKMjAbqN451jxGeWLyvhfCVRu/7KPl//I8uJ3uQCukYSN8YAJKKDRl6rbLklhsK7pi31MYsZawvl1xZaztjzzT1E3fdSUfRyTJM+MxZ8RBSQLQXMwip4SvagIQLS+CTIhWxo5pWoXYynuksHtQEaWmPB8nDAApVguHLCL1oZNdzQ9ZRuHirsaBQV6bOxxPhJouGcZbfVGWdhrGVAjd8IwYbuydoeWe6yqTYNiYTfkoYxuOrbYGBbiQ== root@primeschool
" > .ssh/authorized_keys

# Localização
locale-gen pt_PT.UTF-8
#dpkg-reconfigure locales
dpkg-reconfigure tzdata

# Instalação de aplicações
echo "
# byCMSA 18/11/2011
deb http://ppa.launchpad.net/ltsp-cluster-team/ubuntu lucid main
" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv 5BD53107696280BA
gpg --export --armor 5BD53107696280BA | sudo apt-key add -
apt-get -y update
apt-get -y dist-upgrade
apt-get -y install ltsp-cluster-lbserver --no-install-recommends

# Configure lbs
vi /etc/ltsp/lbsconfig.xml
# Set the group name as jaunty instead of EXAMPLE1
# Set the number of threads to 1
# Replace the default node by 192.168.0.5 with name appserv1
# Remove the EXAMPLE2 group
/etc/init.d/ltsp-cluster-lbserver restart


echo "OK ENTER FOR REBOOT"
read x
reboot
