#!/bin/bash

# LTSP Application Server

. ltsp-include.sh

apt-get -y install ltsp-server ltsp-cluster-lbagent ltsp-cluster-accountmanager $APPLICATIONS || fail "Installing applications"

apt-get -y remove --purge network-manager || fail "Removing network-manager"
apt-get -y remove --purge gnome-orca xscreensaver || fail "Removing gnome-orca xscreensaver"

apt-get autoremove && apt-get autoclean || fail "Cleaning"

update-rc.d -f nbd-server remove || fail "Remove nbd-server from init"
update-rc.d -f gdm remove || fail "Remove gdm from init"
update-rc.d -f bluetooth remove || fail "Remove bluetooth from init"
update-rc.d -f pulseaudio remove || fail "Remove pulseaudio from init"

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
/etc/init.d/ltsp-cluster-lbagent restart || fail "Restarting lbagent"

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

# LDAP
#apt-get -y install libnss-ldap
#vi /etc/ldap.conf --> set tls_checkpeer no
#auth-client-config -t nss -p lac_ldap
#pam-auth-update
#remove use_authtok do ficheiro "vi /etc/pam.d/common-password"
#reboot

# NFS
apt-get -y install nfs-common || fail "Installing NFS common"

if ! [ $(cat /etc/rc.local | grep "start portmap" | wc -l) -gt 0 ]; then
    sed -i "s/^exit 0$/start portmap\n\nexit 0/g" /etc/rc.local || fail "SEDing rc.local"
    start portmap
fi

if ! [ $(cat /etc/fstab | grep "/home /home nfs" | wc -l) -gt 0 ]; then
    echo "$NETWORK.$NFS_SERVER:/home /home nfs rsize=8192,wsize=8192,timeo=14,intr" >> /etc/fstab || fail "configuring mount point"
    mount -a
fi

echo "OK ENTER FOR REBOOT"; read x; reboot

