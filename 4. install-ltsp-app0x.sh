#!/bin/bash

# LTSP Application Server
# 172.31.100.16-...

# SSH
ssh-keygen -t dsa
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAswXDqk2+azGCQuqNRc/faBhGv0WcCP6gNXYt0nhGgOJ3zsP605+sk02Tz3sybJ3RRIylvMdelzOBbY/m5tSt2A5t+6VWWcEJqnroVJJcx24V/pmW7jpAsj68RxwxALU9NhB0vqB7EBoiEaSevH3yCYcqWVmrkNZU7RS4olfwICk= cmsa
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA9xJsdD3E0T6KvjYd/+gF2+lnUWkRyRBx3QcgcVUnj1MkLe8wC1IXQ4bE5VUs/ESj64mLejFVtqxdYheK2r/1im1ZuX7ObkXEQKMjAbqN451jxGeWLyvhfCVRu/7KPl//I8uJ3uQCukYSN8YAJKKDRl6rbLklhsK7pi31MYsZawvl1xZaztjzzT1E3fdSUfRyTJM+MxZ8RBSQLQXMwip4SvagIQLS+CTIhWxo5pWoXYynuksHtQEaWmPB8nDAApVguHLCL1oZNdzQ9ZRuHirsaBQV6bOxxPhJouGcZbfVGWdhrGVAjd8IwYbuydoeWe6yqTYNiYTfkoYxuOrbYGBbiQ== root@primeschool
" > .ssh/authorized_keys

# Localização
locale-gen pt_PT.UTF-8
#dpkg-reconfigure locales
dpkg-reconfigure tzdata

# HOSTS
echo "172.31.100.11 ldap01.primeschool.pt  ldap01" >> /etc/hosts

# Webmin
#echo "
#deb http://download.webmin.com/download/repository sarge contrib
#deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib
#" >> /etc/apt/sources.list
#cd /root
#wget http://www.webmin.com/jcameron-key.asc
#apt-key add jcameron-key.asc
#apt-get -y update
#apt-get -y install webmin

# Instalação de aplicações e limpeza
echo "
# byCMSA 18/11/2011
deb http://ppa.launchpad.net/ltsp-cluster-team/ubuntu lucid main
deb http://ppa.launchpad.net/stgraber/stgraber.net/ubuntu lucid main
deb http://kondr.ic.cz/deb lucid main
deb http://security.ubuntu.com/ubuntu lucid-security main multiverse
" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv DCCB2270E7716B13
gpg --export --armor DCCB2270E7716B13 | sudo apt-key add -
gpg --keyserver keyserver.ubuntu.com --recv 5BD53107696280BA
gpg --export --armor 5BD53107696280BA | sudo apt-key add -
gpg --keyserver keyserver.ubuntu.com --recv 133EE71AB6BC2D37
gpg --export --armor 133EE71AB6BC2D37 | sudo apt-key add -
wget http://www.webmin.com/jcameron-key.asc
apt-key add jcameron-key.asc
apt-get -y update
apt-get -y dist-upgrade
apt-get -y install ubuntu-desktop ltsp-server ltsp-cluster-lbagent ltsp-cluster-accountmanager firefox openoffice.org-l10n-pt openoffice.org-help-pt gcompris-sound-pt language-pack-gnome-pt language-pack-gnome-pt-base language-pack-pt language-pack-pt-base openoffice.org-hyphenation-pt language-support-pt chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen muse nted tuxguitar songwrite salasaga geogebra evince flashplugin-nonfree
apt-get -y remove --purge network-manager
apt-get -y remove --purge gnome-orca xscreensaver
apt-get autoremove && apt-get autoclean
update-rc.d -f nbd-server remove
update-rc.d -f gdm remove
update-rc.d -f bluetooth remove
update-rc.d -f pulseaudio remove
echo "[Desktop Entry]
Version=1.0
Encoding=UTF-8
Name=PulseAudio Session Management
Comment=Load module-suspend-on-idle into PulseAudio
Exec=pactl load-module module-suspend-on-idle
Terminal=false
Type=Application
Categories=
GenericName=
" > /etc/xdg/autostart/pulseaudio-module-suspend-on-idle.desktop
/etc/init.d/ltsp-cluster-lbagent restart

# Configuração ao nível do ambiente de trabalho
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set --type list --list-type string /apps/panel/global/disabled_applets "[OAFIID:GNOME_FastUserSwitchApplet]"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --set --type boolean /desktop/gnome/lockdown/disable_lock_screen True
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --set --type boolean /apps/gnome_settings_daemon/screensaver/start_screensaver False
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set --type integer /apps/gnome-power-manager/timeout/sleep_display_ac 0

# Install Java
mkdir /usr/java
cd /usr/java
scp root@172.31.100.1:~/jre-6u29-linux-i586.bin .
chmod u+x jre-6u29-linux-i586.bin
./jre-6u29-linux-i586.bin
cd /usr/lib/mozilla/plugins
ln -s /usr/java/jre1.6.0_29/lib/i386/libnpjp2.so .

#LDAP
apt-get -y install libnss-ldap
vi /etc/ldap.conf --> set tls_checkpeer no
auth-client-config -t nss -p lac_ldap
pam-auth-update
#remove use_authtok do ficheiro "vi /etc/pam.d/common-password"
#reboot

#NFS
#apt-get install portmap
#dpkg-reconfigure portmap
#/etc/init.d/portmap stop
#update-rc.d -f portmap remove
#update-rc.d portmap start 20  2 3 4 5 . stop 80  0 1 6 .
#/etc/init.d/portmap start
#apt-get install nfs-common

# RC.LOCAL
echo "#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will \"exit 0\" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

/etc/init.d/portmap start
mount -o nolock 172.31.100.12:/home /home

exit 0
" > /etc/rc.local

echo "OK ENTER FOR REBOOT"
read x
reboot

