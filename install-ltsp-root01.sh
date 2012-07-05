#!/bin/bash

# LTSP Root

. ltsp-include.sh

apt-get -y install ltsp-server || fail "Installing ltsp-server"

# Build LTSP Client
echo "When asked for ltsp-cluster settings answer as follow:
	 	Server: $NETWORK.$CONTROL
		Port: 80
		Enable SSL: N
		Inventory: Y
		Timeout: 2
Then when asked, choose a root password.
Options are saved in: [/opt/ltsp/i386/etc/ltsp/getltscfg-cluster.conf]
(PRESS ENTER TO INSTALL LTSP-CLUSTER OR CTRL+C TO CANCEL)"
read x

ltsp-build-client --arch i386 --ltsp-cluster --prompt-rootpass --accept-unsigned-packages --copy-package-lists --locale $LTSP_LANG --copy-sourceslist --skipimage --extra-mirror http://ppa.launchpad.net/stgraber/ubuntu || fail "Building client"
# --fat-client
# I could build fat clients since the computers I am using have 1GB RAM and dual core processors.

# THEME
#cp -a /root/prime_theme /opt/ltsp/i386/usr/share/ldm/themes/
#cd /opt/ltsp/i386/usr/share/ldm/themes/
#rm default
#ln -s prime_theme default

ltsp-update-image --arch i386 -f || fail "Updating image"

echo "OK ENTER FOR REBOOT"; read x; reboot

