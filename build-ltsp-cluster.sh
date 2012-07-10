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

# Create ordered list of containers
VMIDs=$(for id in ${!APPs[@]}; do echo $id; done | sort -n)
PROXMOXs=$(for id in ${!NODEs[@]}; do echo $id; done | sort -n)

function setup_nfs_proxmox() {
    for proxmox in $PROXMOXs; do
        # Setup PROXMOX to be able to run NFS service
        # To be able to run nfs-kernel-server the following modules must be running in PROXMOX node server nfs and nfsd
        ssh $NETWORK.$proxmox "if ! [ $(grep \"modprobe nfs\" /etc/rc.local | wc -l ) -gt 0 ]; then sed -i \"s/^exit 0$/modprobe nfs\nexit 0/g\" /etc/rc.local; fi
        if ! [ $(grep \"modprobe nfsd\" /etc/rc.local | wc -l ) -gt 0 ]; then sed -i \"s/^exit 0$/modprobe nfsd\n\nexit 0/g\" /etc/rc.local; fi
        modprobe nfs
        modprobe nfsd
        echo \"sunrpc.ve_allow_rpc = 1\" >> /etc/sysctl.d/vzctl.conf 
        echo \"fs.nfs.ve_allow_nfs = 1\" >> /etc/sysctl.d/vzctl.conf
        echo \"kernel.ve_allow_kthreads = 1\" >> /etc/sysctl.d/vzctl.conf
        sysctl -p" || fail $HOSTNAME "Setting NFS in PROXMOX nodes"
    done
    rsync -a LTSP-Build-Cluster $NETWORK.$proxmox:/root/
    exit
}

function create_qemu_template_file() {
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
    fi
}

function configure_ssh() {
    # Create SSH key and add root public key into authorized_keys
    if ! [ -s $QEMU_VM_DIR/$CT/root/.ssh/id_rsa ]; then
        echo "$(pcolor yellow)You will be asked three questions, please press ENTER in all to accept default values.
If you can't connect with the error \"Host key verification failed.\":
    delete the corresponding offending key in /root/.ssh/known_hosts
    or
    delete the file /root/.ssh/known_hosts$(pcolor default)"
        chroot $QEMU_VM_DIR/$CT ssh-keygen -t rsa || fail "Generating ssh key"
        cat /root/.ssh/id_rsa.pub >> $QEMU_VM_DIR/$CT/root/.ssh/authorized_keys || fail $HOSTNAME "Importing ssh key"
    fi
    # RSYNC SCRIPTS INTO CONTAINER
    rsync -a LTSP-Build-Cluster $QEMU_VM_DIR/$CT/root/
}

function build_containers() {
    for VMID in $VMIDs; do
        let CT=$CT_OFFSET+$VMID
        echo "$(pcolor yellow)###############################################################################"
        echo "# Processing Container $CT - ${APPs[$VMID]}.$DNS_DOMAIN [$NETWORK.$VMID]"
        echo "###############################################################################$(pcolor default)"
        if ! [ -e $QEMU_VM_CONF_DIR/$CT.conf ]; then
            vzctl create $CT --ostemplate $QEMU_TEMPLATES_DIR/$QEMU_TEMPLATE --hostname ${APPs[$VMID]}.$DNS_DOMAIN --config default || fail $HOSTNAME "Creating container $CT"
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
    gateway $GATEWAY" >> $QEMU_VM_DIR/$CT/etc/network/interfaces || fail $HOSTNAME "Appending to interfaces file"
            else
                SETTINGS="$SETTINGS --ipadd $NETWORK.$VMID"
            fi
            # Regarding NFS
            if [[ ${APPs[$VMID]} == *nfs* ]]; then
                vzctl set $CT --features "nfsd:on" --save || fail $HOSTNAME "Setting nfsd in NFS Server container $CT"
            fi
            vzctl set $CT $SETTINGS --save || fail $HOSTNAME "Setting properties of container $CT"
        fi
        configure_ssh
        # Start container
        vzctl start $CT
        # DEBIAN_FRONTEND is to prevent the message "debconf: unable to initialize frontend: Dialog"
        ssh $NETWORK.$VMID "export DEBIAN_FRONTEND=noninteractive; $(dirname $0)/${APPs[$VMID]}.sh" || fail $HOSTNAME "Running setup script"
    done
}

function build_appservs() {
    IP=$APPSERV_START_IP
    # BUILD APP SERVERS
    for (( VMID=1; VMID<=$APPSERV_NUM; VMID++ ))
    do
        num=$(printf "%02d" $VMID)
        let CT=$CT_OFFSET+$IP
        echo "$(pcolor yellow)###############################################################################"
        echo "# Processing Container $CT - $APPSERV_NAME$num.$DNS_DOMAIN [$NETWORK.$IP]"
        echo "###############################################################################$(pcolor default)"
        if ! [ -e $QEMU_VM_CONF_DIR/$CT.conf ]; then
            vzctl create $CT --ostemplate $QEMU_TEMPLATES_DIR/$QEMU_TEMPLATE --hostname $APPSERV_NAME$num.$DNS_DOMAIN --config default || fail $HOSTNAME "Creating container $CT"
            vzctl set $CT --searchdomain $DNS_DOMAIN --nameserver $DNS_SERVER --ipadd $NETWORK.$IP --swap $APPSERV_SWAP --ram $APPSERV_RAM --diskspace $APPSERV_DISK --onboot yes --userpasswd root:$(cat $ROOT_PASS_FILE) --features nfs:on --save || fail $HOSTNAME "Setting properties of container $CT"
        fi
        configure_ssh
        # Start container
        vzctl start $CT
        ssh $NETWORK.$IP $(dirname $0)/$APPSERV_NAME.sh || fail $HOSTNAME "Running setup script"
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
echo "$(pcolor yellow)###############################################################################
#
# Don't forget to visit:
#   http://$NETWORK.$DHCP_CONTROL_SERVER/ltsp-cluster-control/Admin/
#
# And set (at least most important LDM_SERVER):
# 	LANG = $LTSP_LANG
# 	LDM_DIRECTX = True
# 	LDM_SERVER = %LOADBALANCER%
# 	LOCAL_APPS_MENU = True
# 	SCREEN_07 = ldm
# 	TIMESERVER = ntp.ubuntu.com
# 	XKBLAYOUT = $LANG_CODE
#
# The system is build, now it's up to you!
# You can connect terminals to the network, and boot them by network.
# (or create a VM without disk, booted by network, to test)
#
###############################################################################$(pcolor default)"
