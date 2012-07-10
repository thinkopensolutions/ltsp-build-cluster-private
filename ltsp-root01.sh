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

# LTSP Root
. $(dirname $0)/ltsp-include.sh
HOSTNAME=$(hostname)
if ! [ "$(basename $0)" == "$HOSTNAME.sh" ]; then fail $HOSTNAME "$WRONG_HOSTNAME_MSG"; fi

function build_client() {
    # Build LTSP Client
    echo "$(pcolor yellow)When asked for ltsp-cluster settings answer as follow:
    Server: $NETWORK.$DHCP_CONTROL_SERVER
    Port: 80
    Enable SSL: N
    Inventory: Y
    Timeout: 2
Then when asked, insert the root password.
Options are saved in: [/opt/ltsp/i386/etc/ltsp/getltscfg-cluster.conf]$(pcolor default)"
    ln -sf /opt/ltsp/i386/etc/ltsp/getltscfg-cluster.conf /root/getltscfg-cluster.conf
    ltsp-build-client --arch i386 --ltsp-cluster --prompt-rootpass --accept-unsigned-packages --copy-package-lists --locale $LTSP_LANG --copy-sourceslist --skipimage || fail "Building client"
    # --extra-mirror http://ppa.launchpad.net/stgraber/ubuntu
    # --fat-client
    # I could build fat clients since the computers I am using have 1GB RAM and dual core processors.
    # THEME
    ln -sf /opt/ltsp/i386/usr/share/ldm/themes/ /root/themes
    rsync -a $(dirname $0)/prime_theme /opt/ltsp/i386/usr/share/ldm/themes/
    pushd /opt/ltsp/i386/usr/share/ldm/themes/
    rm default
    ln -sf prime_theme default
    popd
    ltsp-update-image --arch i386 -f || fail "Updating image"
}

configure_lang
update_applications

if ! [ -e /tmp/.aptinstall ]; then
    touch /tmp/.aptinstall
    apt-get -y install ltsp-server || fail "Installing ltsp-server"
    install_ldap_client
    install_nfs_client
    apt-get -y autoremove
fi

if [ -e /opt/ltsp/i386 ]; then
    if [[ $ASK_TO_REBUILD_ROOT_CLIENT -eq 1 ]]; then
        echo -n "$(pcolor yellow)Do you want to rebuild the LTSP client again [y/N]?$(pcolor default) "
        read answer
        if [ "$answer" == "y" ]; then
            "rm" -R /opt/ltsp/i386
            build_client
        fi
    fi
else
    build_client
fi

if ! [ -e /root/.aptrestart ]; then
    touch /root/.aptrestart
    echo "$(pcolor yellow)REBOOT...$(pcolor default)"
    reboot &
fi
