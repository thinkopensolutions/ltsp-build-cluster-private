#!/bin/bash

# SSH
PROXMOX01_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA9xJsdD3E0T6KvjYd/+gF2+lnUWkRyRBx3QcgcVUnj1MkLe8wC1IXQ4bE5VUs/ESj64mLejFVtqxdYheK2r/1im1ZuX7ObkXEQKMjAbqN451jxGeWLyvhfCVRu/7KPl//I8uJ3uQCukYSN8YAJKKDRl6rbLklhsK7pi31MYsZawvl1xZaztjzzT1E3fdSUfRyTJM+MxZ8RBSQLQXMwip4SvagIQLS+CTIhWxo5pWoXYynuksHtQEaWmPB8nDAApVguHLCL1oZNdzQ9ZRuHirsaBQV6bOxxPhJouGcZbfVGWdhrGVAjd8IwYbuydoeWe6yqTYNiYTfkoYxuOrbYGBbiQ== root@primeschool"

# Network
DOMAIN="primeschool.pt"
NETWORK="172.31.100"

# Servers NAME='IP OCTET' (build IP as $NETWORK.$NFS_SERVER)
ROOT=10
CONTROL=11
LOADBALANCER=12
LDAP=26
NFS_SERVER=27
APPSERV="13 14"
declare -A APPs
APPs["10"]="ltsp-root01"
APPs["11"]="ltsp-control01"
APPs["12"]="ltsp-loadbalancer01"
APPs["26"]="ldap01"
APPs["27"]="nfs01"
declare -A APPSERVs
APPSERVs["13"]="ltsp-appserv01"
APPSERVs["14"]="ltsp-appserv02"

# Config
LTSP_LANG="pt_PT.UTF-8"
LANG_CODE="pt"

# Applications
APPLICATIONS_BASE="ubuntu-desktop chromium-browser firefox adobe-flashplugin openoffice.org openoffice.org-hyphenation"
APPLICATIONS_EXTRA="gimp gcompris blender totem banshee pitivi openshot audacity hydrogen muse nted tuxguitar songwrite geogebra evince"
APPLICATIONS_LANG="language-pack-gnome-$LANG_CODE language-pack-gnome-$LANG_CODE-base language-pack-$LANG_CODE language-pack-$LANG_CODE-base openoffice.org-l10n-$LANG_CODE openoffice.org-help-$LANG_CODE gcompris-sound-$LANG_CODE"
APPLICATIONS="$APPLICATIONS_LANG $APPLICATIONS_BASE $APPLICATIONS_EXTRA"

function fail() {
    echo "[FAIL $1]"
    exit -1
}

function configure_ssh() {
    if ! [ -s ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa || fail "Generating ssh key"
        echo "$PROXMOX01_KEY" > .ssh/authorized_keys || fail "Importing ssh key"
    fi
}

function configure_lang() {
    if ! [ "$LANG" == $LTSP_LANG -o $(grep $LTSP_LANG /etc/default/locale | wc -l) -eq 1 ]; then
        locale-gen en_US.UTF-8 || fail "Generating locale en_US.UTF-8"
        locale-gen $LTSP_LANG || fail "Generating locale $LTSP_LANG"
        dpkg-reconfigure locales || fail "Configuring locales"
        dpkg-reconfigure tzdata || fail "Configuring tzdata"
        update-locale LANG=$LTSP_LANG LANGUAGE || fail "Setting LANG to $LTSP_LANG"
    fi
}

configure_ssh
configure_lang

# Avoid to run in next two hours
if ! [ $(find . -mmin -120 -a -name dpkg.log | wc -l) -gt 0 ]; then
    apt-get -y update || fail "Updating repository"
    apt-get -y dist-upgrade || fail "Dist-Upgrading"
fi

