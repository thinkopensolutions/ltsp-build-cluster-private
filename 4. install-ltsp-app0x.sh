#!/bin/bash

# LTSP Application Server
# 172.31.100.13-...

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

apt-get -y install ubuntu-desktop ltsp-server ltsp-cluster-lbagent ltsp-cluster-accountmanager firefox openoffice.org-l10n-pt openoffice.org-help-pt gcompris-sound-pt language-pack-gnome-pt language-pack-gnome-pt-base language-pack-pt language-pack-pt-base openoffice.org-hyphenation chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen muse nted tuxguitar songwrite geogebra evince adobe-flashplugin || fail "Installing apps 1"
apt-get -y remove --purge network-manager || fail "Installing apps 2"
apt-get -y remove --purge gnome-orca xscreensaver || fail "Installing apps 3"
apt-get autoremove && apt-get autoclean || fail "Installing apps 4"
update-rc.d -f nbd-server remove || fail "Installing apps 5"
update-rc.d -f gdm remove || fail "Installing apps 6"
update-rc.d -f bluetooth remove || fail "Installing apps 7"
update-rc.d -f pulseaudio remove || fail "Installing apps 8"

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
" > /etc/xdg/autostart/pulseaudio-module-suspend-on-idle.desktop || fail "pulseaudio-module-suspend-on-idle.desktop"
/etc/init.d/ltsp-cluster-lbagent restart || fail "restarting lbagent"

# Restart the loadbalancer agent:
/etc/init.d/ltsp-cluster-lbagent restart || fail "Restart the loadbalancer agent"

if ! [ -e /dev/fuse ]; then
    # Create fuse device:
    mknod /dev/fuse c 10 229 || fail "Create fuse device"
    # Set access rights on fuse:
    chown root.fuse /dev/fuse || fail "Set access rights on fuse"
    # Set access rights on fuse:
    chmod 660 /dev/fuse || fail "Set access rights on fuse"
fi

# Configuração ao nível do ambiente de trabalho
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set --type list --list-type string /apps/panel/global/disabled_applets "[OAFIID:GNOME_FastUserSwitchApplet]" || fail "gconftool 1"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --set --type boolean /desktop/gnome/lockdown/disable_lock_screen True || fail "gconftool 2"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --set --type boolean /apps/gnome_settings_daemon/screensaver/start_screensaver False || fail "gconftool 3"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set --type integer /apps/gnome-power-manager/timeout/sleep_display_ac 0 || fail "gconftool 4"

# Install Java
#mkdir /usr/java
#cd /usr/java
#scp root@172.31.100.1:~/jre-6u29-linux-i586.bin .
#chmod u+x jre-6u29-linux-i586.bin
#./jre-6u29-linux-i586.bin
#cd /usr/lib/mozilla/plugins
#ln -s /usr/java/jre1.6.0_29/lib/i386/libnpjp2.so .

#LDAP
#apt-get -y install libnss-ldap
#vi /etc/ldap.conf --> set tls_checkpeer no
#auth-client-config -t nss -p lac_ldap
#pam-auth-update
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
#echo "#!/bin/sh -e
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

#/etc/init.d/portmap start
#mount -o nolock 172.31.100.12:/home /home

#exit 0
#" > /etc/rc.local

echo "OK ENTER FOR REBOOT"
read x
reboot

