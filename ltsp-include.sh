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

HOSTNAME=$(hostname)

function pcolor() {
    case "$1" in
		"red") echo -en "\033[0;31m";;
		"lightred") echo -en "\033[1;31m";;
		"green") echo -en "\033[0;32m";;
		"lightgreen") echo -en "\033[1;32m";;
		"yellow") echo -en "\033[0;33m";;
		"lightyellow") echo -en "\033[1;33m";;
		"blue") echo -en "\033[0;34m";;
		"lightblue") echo -en "\033[1;34m";;
		"cyan") echo -en "\033[0;36m";;
		"lightcyan") echo -en "\033[1;36m";;
		"white") echo -en "\033[0;37m";;
		"bold") echo -en "\033[1;37m";;
		*) echo -en "\033[0m";;
	esac
}
function default() { pcolor default; }
function red() { pcolor red; }
function lightred() { pcolor lightred; }
function green() { pcolor green; }
function lightgreen() { pcolor lightgreen; }
function yellow() { pcolor yellow; }
function lightyellow() { pcolor lightyellow; }
function blue() { pcolor blue; }
function lightblue() { pcolor lightblue; }
function cyan() { pcolor cyan; }
function lightcyan() { pcolor lightcyan; }
function white() { pcolor white; }
function bold() { pcolor bold; }

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

function fail() {
    echo "$(red)[$(lightred)FAILURE$(red)] $(blue)[$(lightblue)$HOSTNAME$(blue)]$(default) $1"
    exit -1
}

function success() {
    echo "$(green)[$(lightgreen)SUCCESS$(green)] $(blue)[$(lightblue)$HOSTNAME$(blue)]$(default) $1"
}

function warning() {
    echo "$(cyan)[$(lightcyan)WARNING$(cyan)] $(blue)[$(lightblue)$HOSTNAME$(blue)]$(default) $1"
}

function question() {
    if [ -z "$2" ]; then
        echo -n "$(lightyellow)$1?$(default) "
    else
        echo -n "$(lightyellow)$1 $(yellow)[$(lightyellow)$2$(yellow)]?$(default) "
    fi
}

function add2rclocal() {
    file="/etc/rc.local"
    adding="$1"
    if [ $(cat "$file" | grep "$adding" | wc -l) -lt $(echo "$adding" | wc -l) ]; then
        adding=${adding//\//\\\/}
        if [ $(cat "$file" | grep "$ADDED_BY_END_MSG" | wc -l) -eq 1 ]; then
            sed -i "s/$ADDED_BY_END_MSG/$adding\n$ADDED_BY_END_MSG/g" "$file" || fail "Adding \"$(white)$1$(default)\" into $file"
        else
            sed -i "s/^exit 0$//g" "$file" || fail "Adding \"$(white)$1$(default)\" into $file"
            echo "$ADDED_BY_MSG
$adding
$ADDED_BY_END_MSG

exit 0" >> "$file" || fail "Adding \"$(white)$1$(default)\" into $file"
        fi
        success "Adding \"$(white)$1$(default)\" to file $file"
    fi
    ln -sf $file /root/ltsp-${file##*/} || fail "Creating link to file $file"
}

function add2file() {
    file="$1"
    adding="$2"
    add=${adding//\*/\\\*}
    if ! [ $(cat "$file" | grep "$add" | wc -l) -gt 0 ]; then
        if [ $(cat "$file" | grep "$ADDED_BY_END_MSG" | wc -l) -eq 1 ]; then
            adding=${adding//\//\\\/}
            adding=${adding//\*/\\\*}
            sed -i "s/$ADDED_BY_END_MSG/$adding\n$ADDED_BY_END_MSG/g" "$file" || fail "Adding \"$(white)$2$(default)\" into $file"
        else
            echo "
$ADDED_BY_MSG
$adding
$ADDED_BY_END_MSG
" >> "$file" || fail "Adding \"$(white)$2$(default)\" into $file"
        fi
        success "Adding \"$(white)$2$(default)\" to file $file"
    fi
    ln -sf $file /root/ltsp-${file##*/} || fail "Creating link to file $file"
}

function replace() {
    file="$1"
    param="$2"
    replace="$3"
    param=${param//\//\\\/}
    param=${param//\\n/\\n}
    replace=${replace//\//\\\/}
    replace=${replace//\\n/\\n}
    sed --follow-symlinks -i "s/$param/$replace/g" "$file" || fail "Replacing \"$(white)$2$(default)\" with \"$(white)$3$(default)\" in $file"
    success "Replacing \"$(white)$2$(default)\" with \"$(white)$3$(default)\" in $file"
}

# You call this function with 3 parameters (i) file, (ii) source to be replaced, (iii) new text
# But you can also send a 4th one as a key to validate if a change is necessary
function sed_file() {
    file="$1"
    param="$2"
    replace="$3"
    if [ -z "$4" ]; then
        if [ $(cat "$file" | grep -E "$param" | wc -l) -gt 0 ]; then
            replace "$file" "$param" "$replace"
        fi
    else
        echo cat "$file" | grep -E "$4"
        if ! [ $(cat "$file" | grep -E "$4" | wc -l) -gt 0 ]; then
            replace "$file" "$param" "$replace"
        fi
    fi
    ln -sf $file /root/ltsp-${file##*/} || fail "Creating link to file $file"
}

function configure_lang() {
    if ! [ "$LANG" == $LTSP_LANG -o $(grep $LTSP_LANG /etc/default/locale | wc -l) -gt 0 ]; then
        locale-gen en_US.UTF-8 || fail "Generating locale en_US.UTF-8"
        locale-gen $LTSP_LANG || fail "Generating locale $LTSP_LANG"
        dpkg-reconfigure locales || fail "Configuring locales"
        dpkg-reconfigure tzdata || fail "Configuring tzdata"
        update-locale LANG=$LTSP_LANG LANGUAGE || fail "Setting LANG to $LTSP_LANG"
        echo "$(yellow)Rebooting to set LANGUAGE $LTSP_LANG settings... (PLEASE RUN SCRIPT AGAIN)$(default)"
        /sbin/reboot
        exit 1
    fi
}

function update_applications() {
    if ! [ -e /tmp/ltsp-include.update_applications ]; then
        apt-get -y update || fail "Updating repository"
        apt-get -y install htop tree || fail "Installing utilities"
        apt-get -y dist-upgrade || fail "Dist-Upgrading"
        touch /tmp/ltsp-include.update_applications
    fi
}

function install_ldap_client() {
    add2file /etc/hosts "$NETWORK.$DHCP_LDAP01_SERVER ${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN ${APPs[$DHCP_LDAP01_SERVER]}"
    add2file /etc/hosts "$NETWORK.$DHCP_LDAP02_SERVER ${APPs[$DHCP_LDAP02_SERVER]}.$DOMAIN ${APPs[$DHCP_LDAP02_SERVER]}"
    if ! [ -e /tmp/ltsp-include.install_ldap_client ]; then
        apt-get -y install auth-client-config ldap-auth-client ldap-auth-config libnss-ldap libpam-ldap || fail "Installing ldap client"
        auth-client-config -t nss -p lac_ldap || fail "Running auth-client-config"
        add2file /etc/pam.d/common-session "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077"
        /etc/init.d/libnss-ldap restart || fail "Restarting libnss-ldap"
        # If you need to run setup again:
        #   dpkg-reconfigure ldap-auth-config
        #   pam-auth-update
        # URI in /etc/ldap.conf (should be both): ldap://ldap01.primeschool.pt ldap://ldap02.primeschool.pt
        # DN: dc=primeschool,dc=pt
        # Administrator: cn=admin,dc=primeschool,dc=pt
        touch /tmp/ltsp-include.install_ldap_client
    fi
}

function install_nfs_client() {
    if ! [ -e /tmp/ltsp-include.install_nfs_client ]; then
        apt-get -y install nfs-common || fail "Installing NFS common"
        add2rclocal "start portmap"
        add2file /etc/fstab "$NETWORK.$DHCP_NFS_SERVER:/home /home nfs rsize=8192,wsize=8192,timeo=14,intr,nolock"
        touch /tmp/ltsp-include.install_nfs_client
    fi
}

# Insert all servers in /etc/hosts
VMIDs=$(for id in ${!APPs[@]}; do echo $id; done | sort -n)
for VMID in $VMIDs; do
    if ! [ "${APPs[$VMID]}" == "$HOSTNAME" ]; then
        add2file /etc/hosts "$NETWORK.$VMID ${APPs[$VMID]}.$DOMAIN ${APPs[$VMID]}"
    fi
done
IP=$APPSERV_START_IP
for (( appserv=1; appserv<=$APPSERV_NUM; appserv++ ))
do
    num=$(printf "%02d" $appserv)
    if ! [ "$APPSERV_NAME$num" == "$HOSTNAME" ]; then
	    add2file /etc/hosts "$NETWORK.$IP $APPSERV_NAME$num.$DOMAIN $APPSERV_NAME$num"
    fi
	let IP+=1
done
add2file /etc/hosts "$NETWORK.$DHCP_CUPS_SERVER cups.$DOMAIN cups"

# Check for root password
if ! [ -e $ROOT_PASS_FILE ]; then
    warning "This script has to give the root password to create the containers.
The password you will insert here will be stored in \"$(white)$ROOT_PASS_FILE$(default)\" with 0600 mode."
    echo -n "Please insert the root password: "
    read pass
    echo $pass > $ROOT_PASS_FILE
    chmod 600 $ROOT_PASS_FILE
fi
