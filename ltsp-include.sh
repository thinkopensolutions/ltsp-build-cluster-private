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

source $(dirname $0)/ltsp.config

if ! [ -e $ROOT_PASS_FILE ]; then
    echo "Please create the file \"$ROOT_PASS_FILE\" with root password.
chmod to 600"
    exit
fi

###############################################################################
# SOME PROXMOX DEFAULTS
###############################################################################
QEMU_TEMPLATES_DIR="/var/lib/vz/template/cache"
QEMU_VM_CONF_DIR="/etc/vz/conf"
QEMU_VM_DIR="/var/lib/vz/private"
VZCTL_TEMPLATE_FILE="/etc/pve/openvz/ve-default.conf-sample"
###############################################################################

WRONG_HOSTNAME_MSG="This script must be run only from host $(basename $0)"
ADDED_BY_MSG="# Added by build-ltsp-cluster.sh"
ADDED_BY_END_MSG="# end build-ltsp-cluster.sh"

function pcolor() {
    case "$1" in
		"red") echo -en "\033[1;31m";;
		"green") echo -en "\033[1;32m";;
		"yellow") echo -en "\033[1;33m";;
		*) echo -en "\033[0m";;
	esac
}

function fail() {
    echo "$(pcolor red)[ERROR]$(pcolor yellow)[$1]$(pcolor default) $2"
    exit -1
}

function success() {
    echo "$(pcolor green)[OK]$(pcolor yellow)[$1]$(pcolor default) $2"
}

function add2rclocal() {
    file="/etc/rc.local"
    adding="$1"
    if [ $(grep "$adding" "$file" | wc -l) -lt $(echo "$adding" | wc -l) ]; then
        if [ $(grep "$ADDED_BY_END_MSG" "$file" | wc -l) -eq 1 ]; then
            sed -i "s/$ADDED_BY_END_MSG/$adding\n$ADDED_BY_END_MSG/g" "$file" || fail $HOSTNAME "Adding \"$adding\" into $file"
        else
            sed -i "s/^exit 0$//g" "$file" || fail $HOSTNAME "Adding \"$adding\" into $file"
            echo "$ADDED_BY_MSG
$adding
$ADDED_BY_END_MSG

exit 0" >> "$file" || fail $HOSTNAME "Adding \"$adding\" into $file"
        fi
        success $HOSTNAME "Adding \"$adding\" to file $file"
    fi
}

function add2file() {
    file="$1"
    adding="$2"
    if [ $(grep "$adding" "$file" | wc -l) -lt $(echo "$adding" | wc -l) ]; then
        if [ $(grep "$ADDED_BY_END_MSG" "$file" | wc -l) -eq 1 ]; then
            adding=${adding//\//\\\/}
            sed -i "s/$ADDED_BY_END_MSG/$adding\n$ADDED_BY_END_MSG/g" "$file" || fail $HOSTNAME "Adding \"$adding\" into $file"
        else
            echo "$ADDED_BY_MSG
$adding
$ADDED_BY_END_MSG
" >> "$file" || fail $HOSTNAME "Adding \"$adding\" into $file"
        fi
        success $HOSTNAME "Adding \"$adding\" to file $file"
    fi
}

function sed_file() {
    file="$1"
    param="$2"
    replace="$3"
    if [ $(cat "$file" | grep -E "$param" | wc -l) -gt 0 ]; then
        param=${param//\//\\\/}
        param=${param//\\n/\\n}
        replace=${replace//\//\\\/}
        replace=${replace//\\n/\\n}
        sed --follow-symlinks -i "s/$param/$replace/g" "$file" || fail $HOSTNAME "SED replacing \"$param\" with \"$replace\" in $file"
        success $HOSTNAME "SED replacing \"$param\" with \"$replace\" in $file"
    fi
}

function configure_lang() {
    if ! [ "$LANG" == $LTSP_LANG -o $(grep $LTSP_LANG /etc/default/locale | wc -l) -eq 1 ]; then
        locale-gen en_US.UTF-8 || fail $HOSTNAME "Generating locale en_US.UTF-8"
        locale-gen $LTSP_LANG || fail $HOSTNAME "Generating locale $LTSP_LANG"
        dpkg-reconfigure locales || fail $HOSTNAME "Configuring locales"
        dpkg-reconfigure tzdata || fail $HOSTNAME "Configuring tzdata"
        update-locale LANG=$LTSP_LANG LANGUAGE || fail $HOSTNAME "Setting LANG to $LTSP_LANG"
        echo "$(pcolor yellow)Rebooting to set LANGUAGE $LTSP_LANG settings... (PLEASE RUN SCRIPT AGAIN)$(pcolor default)"
        /sbin/reboot
        exit 1
    fi
}

function update_applications() {
    # Avoid to run
    if ! [ -e /tmp/.apt ]; then
        apt-get -y update || fail $HOSTNAME "Updating repository"
        apt-get -y install htop tree || fail $HOSTNAME "Installing utilities"
        apt-get -y dist-upgrade || fail $HOSTNAME "Dist-Upgrading"
        touch /tmp/.apt
    fi
}

function install_ldap_client() {
    # LDAP Client
    ln -sf /etc/hosts /root/hosts
    if ! [ $(cat /etc/hosts | grep ${APPs[$DHCP_LDAP01_SERVER]} | wc -l) -gt 0 ]; then
        echo "$NETWORK.$DHCP_LDAP01_SERVER ${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN ${APPs[$DHCP_LDAP01_SERVER]}" >> /etc/hosts || fail "Adding ${APPs[$DHCP_LDAP01_SERVER]} to hosts"
        echo "$NETWORK.$DHCP_LDAP02_SERVER ${APPs[$DHCP_LDAP02_SERVER]}.$DOMAIN ${APPs[$DHCP_LDAP02_SERVER]}" >> /etc/hosts || fail "Adding ${APPs[$DHCP_LDAP02_SERVER]} to hosts"
    fi
    
    if ! [ $(grep ${APPs[$DHCP_LDAP01_SERVER]} /etc/ldap.conf | wc -l) -gt 0 ]; then
        apt-get -y install auth-client-config ldap-auth-client ldap-auth-config libnss-ldap libpam-ldap || fail "Installing ldap client"
        auth-client-config -t nss -p lac_ldap
        #If you need to run setup again: dpkg-reconfigure ldap-auth-config
        #If you need to run setup again: pam-auth-update
        add2file /etc/pam.d/common-session "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077"
        /etc/init.d/libnss-ldap restart
        # URI in /etc/ldap.conf must be (both): ldap://ldap01.primeschool.pt ldap://ldap02.primeschool.pt
        # DN: dc=primeschool,dc=pt
        # Administrator: cn=admin,dc=primeschool,dc=pt
    fi
}

function install_nfs_client() {
    # NFS
    if ! [ $(grep $NETWORK.$DHCP_NFS_SERVER /etc/fstab | wc -l) -gt 0 ]; then
        apt-get -y install nfs-common || fail "Installing NFS common"
        add2rclocal "start portmap"
        add2file /etc/fstab "$NETWORK.$DHCP_NFS_SERVER:/home /home nfs rsize=8192,wsize=8192,timeo=14,intr,nolock"
    fi
}

