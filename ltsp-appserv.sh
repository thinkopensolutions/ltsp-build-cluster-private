#!/bin/bash

###############################################################################
#
# Copyright (C) 2012 Thinkopen Solutions, Lda. All Rights Reserved
# http://www.thinkopensolutions.com.
#
# Carlos Miguel Sousa Almeida
# cma@thinkopensolutions.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

# LTSP Application Server
. $(dirname $0)/ltsp-include.sh
base=$(basename $0)
base=${base/.sh}
if ! [[ "$HOSTNAME" == "$base"* ]]; then fail $HOSTNAME "$WRONG_HOSTNAME_MSG"; fi

configure_lang
update_applications

if ! [ -e /tmp/ltsp-appserv.install ]; then
    apt-get -y install cups ltsp-server ltsp-cluster-lbagent ltsp-cluster-accountmanager $APPLICATIONS || fail "Installing ltsp"
    # Troubleshoot the halt during login in ##########################################
    # As in #39: https://bugs.launchpad.net/ubuntu/+source/at-spi2-core/+bug/870874
    # comment all file 90qt-a11y and install nscd
    #  it turns out that I don't need to comment the file (I tried that:)
    #sed_file /etc/X11/Xsession.d/90qt-a11y "^" "#"
    apt-get -y install nscd || fail "Installing nscd"
    # really solved the problem cma@thinkopensolutions.com 12/07/2012
    ##################################################################################
    apt-get -y autoremove && apt-get -y autoclean || fail "Cleaning"
    add2file /etc/hosts "$NETWORK.$DHCP_CUPS_SERVER cups.$DOMAIN cups"
    touch /tmp/ltsp-appserv.install
fi

install_ldap_client || fail "Installing LDAP client"
install_nfs_client || fail "Installing NFS client"

sed_file /etc/cups/cupsd.conf "^Listen localhost:631$" "#Listen localhost:631"
sed_file /etc/cups/cupsd.conf "^Listen /var/run/cups/cups.sock$" "#Listen /var/run/cups/cups.sock\nPort 631" "^Listen ${APPs[$DHCP_CONTROL_SERVER]}:631$"
sed_file /etc/cups/cupsd.conf "Browsing Off" "Browsing On"
add2file /etc/pam.d/common-session "session optional pam_ecryptfs.so unrwap"
add2file /etc/pam.d/common-session "session optional pam_ck_connector.so nox11"

if ! [ -e /tmp/ltsp-appserv.setup ]; then
    apt-get -y remove --purge gnome-screensaver compiz network-manager gnome-orca xscreensaver || fail "Cleaning"
    apt-get -y autoremove && apt-get -y autoclean || fail "Cleaning"
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
    touch /tmp/ltsp-appserv.setup
fi

if ! [ -e /root/ltsp-appserv.reboot ]; then
    touch /root/ltsp-appserv.reboot
    warning "REBOOTING..."
    reboot &
fi

