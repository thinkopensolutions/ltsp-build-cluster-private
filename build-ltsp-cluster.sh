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

# This Script Builds all LTSP Cluster Servers
# See ltsp.config file to configure it all
source $(dirname $0)/ltsp-include.sh

function setup_nfs_proxmox() {
    echo "$(yellow)###############################################################################"
    echo "# $(lightyellow)Setup PROXMOX nodes for NFS"
    echo "$(yellow)###############################################################################$(default)"
    PROXMOXs=$(for id in ${!NODEs[@]}; do echo $id; done | sort -n)
    for proxmox in $PROXMOXs; do
        if ! [ -e /root/.build-ltsp-cluster.${NODEs[$proxmox]} ]; then
            # Copy scripts
            rsync -a $(dirname $0) $NETWORK.$proxmox:/root/ || fail "RSYNC scripts to ${NODEs[$proxmox]} [$NETWORK.$proxmox]"
            rsync -a $ROOT_PASS_FILE $NETWORK.$proxmox:$ROOT_PASS_FILE || fail "RSYNC password file to ${NODEs[$proxmox]} [$NETWORK.$proxmox]"
            # Setup PROXMOX to be able to run NFS service
            # To be able to run nfs-kernel-server the following modules must be running in PROXMOX node server nfs and nfsd
            ssh $NETWORK.$proxmox $(dirname $0)/set_nfs.sh || fail "Setting NFS in PROXMOX nodes"
            touch /root/.build-ltsp-cluster.${NODEs[$proxmox]}
            success "Setting node ${NODEs[$proxmox]} [$NETWORK.$proxmox]"
        fi
    done
}

function create_qemu_template_file() {
    echo "$(yellow)###############################################################################"
    echo "# $(lightyellow)Creating VZ template for containers"
    echo "$(yellow)###############################################################################$(default)"
    # Get Ubuntu 12.04 precreated template
    if ! [ -e $QEMU_TEMPLATES_DIR/$QEMU_TEMPLATE ]; then
        wget http://download.openvz.org/template/precreated/$QEMU_TEMPLATE
        mv $QEMU_TEMPLATE $QEMU_TEMPLATES_DIR
    fi
    if ! [ -e $VZCTL_TEMPLATE_FILE ]; then
        vzsplit -n 10 -f default
        sed_file $VZCTL_TEMPLATE_FILE "^DISKSPACE=.*" "DISKSPACE=\"2G:2200M\""
        sed_file $VZCTL_TEMPLATE_FILE "^PHYSPAGES=.*" "PHYSPAGES=\"0:1024M\""
        sed_file $VZCTL_TEMPLATE_FILE "^SWAPPAGES=.*" "SWAPPAGES=\"0:512M\""
        success "Setting node ${NODEs[$proxmox]} [$NETWORK.$proxmox]"
    fi
}

function configure_ssh() {
    # Create SSH key and add root public key into authorized_keys
    if ! [ -s $QEMU_VM_DIR/$CT/root/.ssh/id_rsa ]; then
        warning "You will be asked three questions, please press ENTER in all to accept default values.
If you can't connect with the error \"$(white)Host key verification failed$(default)\" do one of following:
    a) delete the corresponding offending key in /root/.ssh/known_hosts
    b) delete the file /root/.ssh/known_hosts"
        chroot $QEMU_VM_DIR/$CT ssh-keygen -t rsa || fail "Generating ssh key"
        cat /root/.ssh/id_rsa.pub >> $QEMU_VM_DIR/$CT/root/.ssh/authorized_keys || fail "Importing ssh key"
    fi
    # RSYNC SCRIPTS INTO CONTAINER
    rsync -a $(dirname $0) $QEMU_VM_DIR/$CT/root/
    rsync -a $ROOT_PASS_FILE $NETWORK.$proxmox:$ROOT_PASS_FILE
}

function build_containers() {
    for VMID in $VMIDs; do
        let CT=$CT_OFFSET+$VMID
        echo "$(yellow)###############################################################################"
        echo "# $(lightyellow)Processing Container $CT - ${APPs[$VMID]}.$DNS_DOMAIN [$NETWORK.$VMID]"
        echo "$(yellow)###############################################################################$(default)"
        if ! [ -e $QEMU_VM_CONF_DIR/$CT.conf ]; then
            vzctl create $CT --ostemplate $QEMU_TEMPLATES_DIR/$QEMU_TEMPLATE --hostname ${APPs[$VMID]}.$DNS_DOMAIN --config default || fail "Creating container $CT"
            SETTINGS="--onboot yes --searchdomain $DNS_DOMAIN --nameserver $DNS_SERVER --swap ${SWAPS[${APPs[$VMID]}]} --ram ${RAMS[${APPs[$VMID]}]} --diskspace ${DISKS[${APPs[$VMID]}]} --userpasswd root:$(cat $ROOT_PASS_FILE) --features nfs:on"
            # Regarding DHCP
            if [[ ${APPs[$VMID]} == *dhcp* ]]; then
                # Create dhcp containers with veth network devices to be able to broadcast to network
                SETTINGS="$SETTINGS --netif_add eth0,,,,"
                # Create interface eth0 to be able to start network on first boot
                echo "
auto eth0
iface eth0 inet static
    address $NETWORK.$VMID
    netmask 255.255.255.0
    broadcast $NETWORK.255
    gateway $GATEWAY" >> $QEMU_VM_DIR/$CT/etc/network/interfaces || fail "Appending to interfaces file"
            else
                SETTINGS="$SETTINGS --ipadd $NETWORK.$VMID"
            fi
            # Regarding NFS
            if [[ ${APPs[$VMID]} == *nfs* ]]; then
                vzctl set $CT --features "nfsd:on" --save || fail "Setting nfsd in NFS Server container $CT"
            fi
            vzctl set $CT $SETTINGS --save || fail "Setting properties of container $CT"
        fi
        configure_ssh
        # Start container
        vzctl start $CT
        # DEBIAN_FRONTEND is to prevent the message "debconf: unable to initialize frontend: Dialog"
        rsync -a $ROOT_PASS_FILE $NETWORK.$VMID:$ROOT_PASS_FILE || fail "RSYNC password file to ${APPs[$VMID]} [$NETWORK.$VMID]"
        ssh $NETWORK.$VMID "export DEBIAN_FRONTEND=noninteractive; $(dirname $0)/${APPs[$VMID]}.sh" || fail "Creating container (maybe rebooting)!"
    done
}

function build_appservs() {
    IP=$APPSERV_START_IP
    # BUILD APP SERVERS
    for (( VMID=1; VMID<=$APPSERV_NUM; VMID++ ))
    do
        num=$(printf "%02d" $VMID)
        let CT=$CT_OFFSET+$IP
        echo "$(yellow)###############################################################################"
        echo "# $(lightyellow)Processing Container $CT - $APPSERV_NAME$num.$DNS_DOMAIN [$NETWORK.$IP]"
        echo "$(yellow)###############################################################################$(default)"
        if ! [ -e $QEMU_VM_CONF_DIR/$CT.conf ]; then
            vzctl create $CT --ostemplate $QEMU_TEMPLATES_DIR/$QEMU_TEMPLATE --hostname $APPSERV_NAME$num.$DNS_DOMAIN --config default || fail "Creating container $CT"
            vzctl set $CT --searchdomain $DNS_DOMAIN --nameserver $DNS_SERVER --ipadd $NETWORK.$IP --swap $APPSERV_SWAP --ram $APPSERV_RAM --diskspace $APPSERV_DISK --onboot yes --userpasswd root:$(cat $ROOT_PASS_FILE) --features nfs:on --save || fail "Setting properties of container $CT"
        fi
        configure_ssh
        # Start container
        vzctl start $CT
        ssh $NETWORK.$IP $(dirname $0)/$APPSERV_NAME.sh || fail "Running setup script"
        let IP+=1
    done
}

function usage {
	echo "Usage build-ltsp-cluster.sh [--stop-all]
Options:
 --stop-all       Stop all LTSP Cluster containers"
}

# Create LTSP Cluster containers
setup_nfs_proxmox
create_qemu_template_file
build_containers
build_appservs

echo "$(yellow)###############################################################################
#
# $(lightyellow)Don't forget to visit:$(yellow)
#   http://$NETWORK.$DHCP_CONTROL_SERVER/ltsp-cluster-control/Admin/
#
# $(lightyellow)And set (at least the most important LDM_SERVER):$(yellow)
# 	LANG = $LTSP_LANG
# 	LDM_DIRECTX = True
# 	LDM_SERVER = %LOADBALANCER%
# 	LOCAL_APPS_MENU = True
# 	SCREEN_07 = ldm
# 	TIMESERVER = ntp.ubuntu.com
# 	XKBLAYOUT = $LANG_CODE
#
# $(lightcyan)The system is build, now it's up to you!$(yellow)
# You can connect terminals to the network, and boot them by network.
# (or create a VM without disk, booted by network, to test)
#
###############################################################################$(default)"
