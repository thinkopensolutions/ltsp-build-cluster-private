#!/bin/bash
# by Carlos Almeida at 18/09/2011
#    cma@thinkopensolutions.com

LOG_FILE="LTSP-RebuildClient.log"

CHROOT=/opt/ltsp/i386
VAR_PATH=/var/lib/tftpboot/ltsp/i386
LDM_PATH=$CHROOT/usr/share/ldm

PRIME_THEME="/home/carlosalmeida/Dropbox/Empresas/4Himself Ensino Lda/Informática/Scripts/prime_theme"

echo "Please consult logs in $LOG_FILE"
echo $(date) > $LOG_FILE
echo "Creating 1st client image..." &&
	ltsp-build-client &&
        #sudo ltsp-build-client --fat-client --fat-client-desktop ubuntu-desktop --accept-unsigned-packages --prompt-rootpass --skipimage --purge-chroot --copy-sourceslist --apt-keys A3436E8D,3E5C1192
	ls $CHROOT &&
	echo -n "OK?"; read &&
echo "Copying host repositories to client..." &&
	$(echo "deb http://ppa.launchpad.net/edubuntu-italc-devel/ubuntu hardy main" >> /etc/apt/sources.list) &&
	$(echo "deb-src http://ppa.launchpad.net/edubuntu-italc-devel/ubuntu hardy main" >> /etc/apt/sources.list) &&
	cp /etc/apt/sources.list $CHROOT/etc/apt/sources.list &&
	cat $CHROOT/etc/apt/sources.list &&
	echo -n "OK?"; read &&
echo "Setup PRIME theme for the terminals..." &&
	cp -r "$PRIME_THEME" $LDM_PATH/themes/ &&
	chown -R root.root $LDM_PATH/themes/prime_theme &&
	cd $LDM_PATH/themes/ &&
	ln -sf prime_theme default &&
	cd - &&
	ls -l $LDM_PATH/themes &&
	echo -n "OK?"; read &&
echo "Configuring chroot mount points..." &&
	mount --bind /dev $CHROOT/dev &&
	mount -t proc none $CHROOT/proc &&
	mount &&
	echo -n "OK?"; read &&
	echo "Update repositories..." &&
		chroot $CHROOT apt-get update -y &&
		chroot $CHROOT apt-get dselect-upgrade -y &&
		echo -n "OK?"; read &&
	echo "Installing software in client..." &&
		chroot $CHROOT apt-get install firefox firefox-locale-pt firefox-globalmenu sun-java6-plugin flashplugin-nonfree chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen-drumkits muse nted playitslowly tuxguitar songwrite videoporama salasaga unity language-pack-gnome-pt language-pack-gnome-pt-base language-support-pt language-support-writing-pt libreoffice libreoffice-help-pt libreoffice-help-pt-br libreoffice-l10n-common libreoffice-l10n-pt libreoffice-l10n-pt-br maint-guide-pt-br manpages-pt apturl evince manpages-pt-dev nautilus -y &&
		echo -n "OK?"; read &&
	echo "Installing and configuring local language..." &&
		chroot $CHROOT apt-get install language-pack-pt -y &&
		chroot $CHROOT locale-gen &&
		chroot $CHROOT update-locale LANG=pt_PT.UTF-8 LC_ALL=pt_PT.UTF-8 &&
		chroot $CHROOT echo a4 > $CHROOT/etc/papersize &&
		chroot $CHROOT echo 'LANGUAGE="pt_PT:en_US:en"
LC_ALL="pt_PT.UTF-8"
LC_PAPER=a4' >> $CHROOT/etc/environment &&
		chroot $CHROOT echo 'LANGUAGE="pt_PT:en_US:en"
LC_ALL="pt_PT.UTF-8"
LC_PAPER=a4' >> $CHROOT/etc/default/locale &&
		chroot $CHROOT echo 'pref("browser.startup.homepage", "http://www.colegioinfanta.pt");' >> $CHROOT/etc/firefox/syspref.js &&
		chroot $CHROOT echo 'pref("print.postscript.paper_size", "A4");' >> $CHROOT/etc/firefox/syspref.js &&
		cat $CHROOT/etc/papersize &&
		echo -n "OK?"; read &&
		cat $CHROOT/etc/environment &&
		echo -n "OK?"; read &&
		cat $CHROOT/etc/default/locale &&
		echo -n "OK?"; read &&
		cat $CHROOT/etc/firefox/syspref.js &&
		echo -n "OK?"; read &&
	echo "Installing italc-client..." &&
		chroot $CHROOT apt-get install italc-client -y &&
		echo -n "OK?"; read &&
	echo "Configuring extra scripts to access extramounts..." &&
		cd /opt/ltsp/i386/usr/share/ldm/rc.d &&
		sudo wget http://www.carlit.net/upload/X02-localapps-addons &&
		sudo wget http://www.carlit.net/upload/X98-localapps-addons-cleanup &&
		ls -l &&
		echo -n "OK?"; read &&
echo "Closing CHROOT..." &&
	umount $CHROOT/dev &&
	umount $CHROOT/proc &&
	mount &&
	echo -n "OK?"; read &&
echo "Updating client image..." &&
	ltsp-update-image --arch i386 &&
	echo -n "OK?"; read &&
echo "Re-Setup italc keys..." &&
	"rm" -R /etc/italc/keys &&
	cp -r $CHROOT/etc/italc/keys /etc/italc/ &&
	chgrp teachers /etc/italc/keys/private/teacher/key &&
	chgrp admin /etc/italc/keys/private/supporter/key &&
	chgrp admin /etc/italc/keys/private/admin/key &&
	ls -l /etc/italc/keys/private/teacher/
	echo -n "OK?"; read &&
echo "Setup lts.conf file..." &&
echo "
# Global defaults for all clients
# if you refer to the local server, just use the
# \"server\" keyword as value 
# see lts_parameters.txt for valid values
# version $(date)
################
[default]
  SEARCH_DOMAIN=infantaLTSP01
  DNS_SERVER=172.31.100.254
  CUPS_SERVER = 172.31.100.2

  LOCALDEV=True
  NBD_SWAP=True
  SYSLOG_HOST=server
  XKBLAYOUT=pt

  X_COLOR_DEPTH=24
  SOUND=True
  VOLUME=80
  PCM_VOLUME=80
  FRONT_VOLUME=80
  CD_VOLUME=80
  HEADPHONE_VOLUME=80

  LDM_DEBUG=False
  LDM_DIRECTX=True
  LDM_NUMLOCK=True
  LDM_LANGUAGE=\"pt_PT.UTF-8\"
  LDM_LIMIT_ONE_SESSION=True
  LDM_LIMIT_ONE_SESSION_PROMPT=True

  LOCAL_APPS=True
  LOCAL_APPS_MENU=True
  LOCAL_APPS_MENU_ITEMS=firefox,chromium-browser,gimp,blender,totem,banshee,pitivi,openshot,audacity,hydrogen-drumkits,muse,nted,playitslowly,tuxguitar,songwrite,videoporama,salasaga,evince,libreoffice
  LOCAL_APPS_EXTRAMOUNTS=/home,/media,/opt

  #apturl,audacity,blender-fullscreen,compiz,openjdk-6-policytool,salasaga,sun-java6-java,totem,banshee,blender-windowed,firefox,muse,openshot,software-properties-gtk,sun-java6-javaws,tuxguitar,banshee-audiocd,chromium,gimp,nted,pitivi,songwrite,sun-java6-policytool,videoporama,banshee-media-player,chromium-browser,gksu,openjdk-6-java,playitslowly,sun-java6-controlpanel,synaptic,libreoffice,evince

  START_ITALC=True

###############
# Computador com impressora paralela
###############
[00:16:EC:C7:9F:D1]
  PRINTER_0_TYPE=P
  PRINTER_0_DEVICE=/dev/lp0

" > $VARPATH/lts.conf &&
head $VARPATH/lts.conf &&
echo -n "OK?"; read

ERR=$?

if [ $ERR == 0 ]; then
	echo " [DONE]"
else
	echo " [ERROR]"
	#tail --lines=5 $LOG_FILE
	exit
fi

echo "
$(date)
[DONE]"

