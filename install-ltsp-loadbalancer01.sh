#!/bin/bash

# LTSP Load Balancer

. ltsp-include.sh
. /etc/lsb-release

apt-get -y install ltsp-cluster-lbserver  || fail "Installing ltsp-cluster-lbserver"

for appserv in $APPSERV; do
    if ! [ $(cat /etc/hosts | grep ${APPSERVs[$appserv]} | wc -l) -gt 0 ]; then
        echo "$NETWORK.$appserv ${APPSERVs[$appserv]}.$DOMAIN ${APPSERVs[$appserv]}" >> /etc/hosts || fail "Adding ${APPSERVs[$appserv]} to hosts"
    fi
done

# Configure lbs
sed -i "s/yourdomain.com/$DOMAIN/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"
sed -i "s/max-threads=\"2\"/max-threads=\"1\"/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"
sed -i "s/<group default=\"true\" name=\"default\">/<group default=\"true\" name=\"$DISTRIB_CODENAME\">/g" /etc/ltsp/lbsconfig.xml || fail "SEDing lbsconfig.xml"

/etc/init.d/ltsp-cluster-lbserver restart || fail "Restarting lbs server"

echo "OK ENTER FOR REBOOT"; read x; reboot

