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

# LDAP Server Consumer (HA REPLICATION)
. $(dirname $0)/ldap-include.sh
HOSTNAME=$(hostname)
if ! [ "$(basename $0)" == "$HOSTNAME.sh" ]; then fail $HOSTNAME "$WRONG_HOSTNAME_MSG"; fi

# Upstream documentation https://help.ubuntu.com/12.04/serverguide/openldap-server.html

configure_lang
update_applications

if ! [ -e /tmp/.aptinstall ]; then
    touch /tmp/.aptinstall
    apt-get -y install slapd ldap-utils gnutls-bin ssl-cert || fail "Installing LDAP Server and Client (to webmin)"
    apt-get -y autoremove
fi

install_webmin
install_ldap_client
install_nfs_client

sed_file /etc/ldap.conf "^#host 127.0.0.1$" "host 127.0.0.1"
sed_file /etc/ldap.conf "^uri ldap://${APPs[$DHCP_LDAP02_SERVER]}" "#uri ldap://${APPs[$DHCP_LDAP02_SERVER]}"

add_indexes
replication_consumer_side

