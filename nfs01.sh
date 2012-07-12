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

# NFS01
. $(dirname $0)/ltsp-include.sh
if ! [ "$(basename $0)" == "$HOSTNAME.sh" ]; then fail $HOSTNAME "$WRONG_HOSTNAME_MSG"; fi

configure_lang
update_applications

if ! [ -e /tmp/ltsp-nfs01.install ]; then
    apt-get -y install nfs-kernel-server || fail "Installing nfs-kernel-server"
    apt-get -y autoremove && apt-get -y autoclean || fail "Cleaning"
    touch /tmp/ltsp-nfs01.install
fi

install_ldap_client || fail "Installing LDAP client"

add2rclocal "start portmap"
add2rclocal "/etc/init.d/nfs-kernel-server start"
add2file /etc/exports "/home *(rw,sync,no_root_squash,no_subtree_check) # LTSP Home mount point"

if ! [ -e /root/ltsp-nfs01.reboot ]; then
    touch /root/ltsp-nfs01.reboot
    warning "REBOOTING..."
    reboot &
fi
