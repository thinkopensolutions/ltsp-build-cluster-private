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

# DHCP01
. $(dirname $0)/ltsp-include.sh
HOSTNAME=$(hostname)
if ! [ "$(basename $0)" == "$HOSTNAME.sh" ]; then fail $HOSTNAME "$WRONG_HOSTNAME_MSG"; fi

configure_lang
update_applications

if ! [ -e /tmp/.aptinstall ]; then
    touch /tmp/.aptinstall
    apt-get -y install isc-dhcp-server
    apt-get -y autoremove
fi

dhcp_file="/etc/dhcp/dhcpd.conf"

ln -sf $dhcp_file /root/dhcpd.conf
ln -sf /etc/default/isc-dhcp-server /root/isc-dhcp-server
#sed_file $dhcp_file "^#authoritative;$" "authoritative;"
sed_file $dhcp_file "^option domain-name" "# option domain-name"
sed_file /etc/default/isc-dhcp-server "^INTERFACES=\"\"$" "INTERFACES=\"eth0\""
  
if ! [ $(grep "failover peer" $dhcp_file | wc -l) -gt 0 ]; then
    echo "$ADDED_BY_MSG
failover peer \"dhcp-failover\" {
  primary; # declare this to be the primary server
  address $NETWORK.$DHCP_MAIN;
  port 647;
  peer address $NETWORK.$DHCP_BACKUP;
  peer port 647;
  max-response-delay 30;
  max-unacked-updates 10;
  load balance max seconds 3;
  mclt 1800;
  split 128;
}

subnet $NETWORK.0 netmask 255.255.255.0 {
  option domain-name \"$DNS_DOMAIN\";
  option domain-name-servers $GATEWAY, $DNS_SERVER;
  option routers $GATEWAY;
  option broadcast-address $NETWORK.255;
  next-server $NETWORK.$DHCP_ROOT_SERVER;
  option root-path \"/opt/ltsp/i386\";

  if substring( option vendor-class-identifier, 0, 9 ) = \"PXEClient\" {
      filename \"/ltsp/i386/pxelinux.0\";
  } else {
      filename \"/ltsp/i386/nbi.img\";
  }

  pool {
    failover peer \"dhcp-failover\";
    max-lease-time 600;
    range $NETWORK.$DHCP_POOL_INI $NETWORK.$DHCP_POOL_FIN;
  }

  host firebird {
    hardware ethernet 96:9E:72:50:45:6F;
    fixed-address 172.31.100.240;
  }

  host winxp {
    hardware ethernet C6:8B:99:9C:99:50;
    fixed-address 172.31.100.241;
  }
}" >> $dhcp_file || fail $HOSTNAME "Appending to $dhcp_file file"
fi

if ! [ -e /root/.aptrestart ]; then
    touch /root/.aptrestart
    echo "$(pcolor yellow)REBOOT...$(pcolor default)"
    reboot &
fi

