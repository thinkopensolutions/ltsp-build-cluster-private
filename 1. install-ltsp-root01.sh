#!/bin/bash

# LTSP Root
# 172.31.100.10

function fail() {
    echo "[FAIL $1]"
    exit -1
}

# SSH
ssh-keygen -y -t rsa || fail "Generating ssh key"
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA9xJsdD3E0T6KvjYd/+gF2+lnUWkRyRBx3QcgcVUnj1MkLe8wC1IXQ4bE5VUs/ESj64mLejFVtqxdYheK2r/1im1ZuX7ObkXEQKMjAbqN451jxGeWLyvhfCVRu/7KPl//I8uJ3uQCukYSN8YAJKKDRl6rbLklhsK7pi31MYsZawvl1xZaztjzzT1E3fdSUfRyTJM+MxZ8RBSQLQXMwip4SvagIQLS+CTIhWxo5pWoXYynuksHtQEaWmPB8nDAApVguHLCL1oZNdzQ9ZRuHirsaBQV6bOxxPhJouGcZbfVGWdhrGVAjd8IwYbuydoeWe6yqTYNiYTfkoYxuOrbYGBbiQ== root@primeschool" > .ssh/authorized_keys || fail "Importing ssh key"
locale-gen en_US.UTF-8 || fail "Generating locale en_US.UTF-8"
locale-gen pt_PT.UTF-8 || fail "Generating locale pt_PT.UTF-8"
dpkg-reconfigure locales || fail "Configuring locales"
dpkg-reconfigure tzdata || fail "Configuring tzdata"

# Instalação de aplicações
#echo "
# byCMSA 18/11/2011
#deb http://ppa.launchpad.net/ltsp-cluster-team/ubuntu lucid main
#deb http://ppa.launchpad.net/stgraber/stgraber.net/ubuntu lucid main
#deb http://security.ubuntu.com/ubuntu lucid-security main multiverse
#deb http://archive.ubuntu.com/ubuntu lucid-security main restricted universe
#deb http://kondr.ic.cz/deb lucid main
#" >> /etc/apt/sources.list
#gpg --keyserver keyserver.ubuntu.com --recv 5BD53107696280BA
#gpg --export --armor 5BD53107696280BA | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv DCCB2270E7716B13
#gpg --export --armor DCCB2270E7716B13 | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv 133EE71AB6BC2D37
#gpg --export --armor 133EE71AB6BC2D37 | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv DCCB2270E7716B13
#gpg --export --armor DCCB2270E7716B13 | sudo apt-key add -
#wget http://kondr.ic.cz/kondr.key -O- | sudo apt-key add -
apt-get -y update || fail "Updating repository"
apt-get -y dist-upgrade || fail "Dist-upgrading"

#TRY
#  vi /etc/xinetd.d/tftp and make disable = no. Otherwise tftp not work.
#  /etc/init.d/xinetd restart
#BEFORE
#apt-get -y remove xinetd
apt-get -y install ltsp-server || fail "Installing ltsp-server"
# openbsd-inetd
#apt-get -y install ltsp-server --no-install-recommends

# Build LTSP Client
echo "When asked for ltsp-cluster settings answer as follow:
	 	Server: 172.31.100.11 (control)
		Port: 80
		Enable SSL: N
		Inventory: Y
		Timeout: 2
Then when asked, choose a root password.
Options are saved in: [/opt/ltsp/i386/etc/ltsp/getltscfg-cluster.conf]
Press ENTER"
read x
ltsp-build-client --arch i386 --ltsp-cluster --prompt-rootpass --accept-unsigned-packages --copy-package-lists --locale pt_PT.UTF-8 --copy-sourceslist  --skipimage --extra-mirror http://ppa.launchpad.net/stgraber/ubuntu || fail "ltsp-build-client"
# --fat-client
# I build fat clients since the computers I am using have 1GB RAM and dual core processors.

# THEME
#cp -a /root/prime_theme /opt/ltsp/i386/usr/share/ldm/themes/
#cd /opt/ltsp/i386/usr/share/ldm/themes/
#rm default
#ln -s prime_theme default

#JAVA
#cp -a /root/java /opt/ltsp/i386/usr/
#cd /opt/ltsp/i386/usr/lib/mozilla/plugins
#ln -s ../../../java/latest/lib/i386/libnpjp2.so .

#Change to CHROOT
#mount --bind /dev /opt/ltsp/i386/dev
#mount -t proc none /opt/ltsp/i386/proc
#chroot /opt/ltsp/i386/
#echo "
## byCMSA 18/11/2011
#deb http://ppa.launchpad.net/ltsp-cluster-team/ubuntu lucid main
#deb http://ppa.launchpad.net/stgraber/stgraber.net/ubuntu lucid main
#deb http://security.ubuntu.com/ubuntu lucid-security main multiverse
#deb http://archive.ubuntu.com/ubuntu lucid-security main restricted universe
#deb http://kondr.ic.cz/deb lucid main
#" >> /etc/apt/sources.list
#gpg --keyserver keyserver.ubuntu.com --recv 5BD53107696280BA
#gpg --export --armor 5BD53107696280BA | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv DCCB2270E7716B13
#gpg --export --armor DCCB2270E7716B13 | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv 133EE71AB6BC2D37
#gpg --export --armor 133EE71AB6BC2D37 | sudo apt-key add -
#gpg --keyserver keyserver.ubuntu.com --recv DCCB2270E7716B13
#gpg --export --armor DCCB2270E7716B13 | sudo apt-key add -
#wget http://kondr.ic.cz/kondr.key -O- | sudo apt-key add -
#apt-get -y update
#apt-get -y install firefox chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen muse nted tuxguitar songwrite salasaga geogebra evince flashplugin-nonfree
#exit # (CTRL+D)
#umount /opt/ltsp/i386/dev
#umount /opt/ltsp/i386/proc

ltsp-update-image --arch i386 -f || fail "ltsp-update-image"

echo "OK ENTER FOR REBOOT"
read x
reboot

