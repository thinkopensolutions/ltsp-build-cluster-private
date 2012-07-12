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
# Upstream documentation https://help.ubuntu.com/12.04/serverguide/openldap-server.html

. $(dirname $0)/ltsp-include.sh

function ask_ldap_pass() {
    warning "This script has to give a password for LDAP configuration."
    echo -n "Please insert the admin LDAP password: "
    read pass
    echo $pass
}

function install_webmin() {
    # Install Webmin
    add2file /etc/apt/sources.list "deb http://download.webmin.com/download/repository sarge contrib"
    add2file /etc/apt/sources.list "deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib"
    cd /root
    if ! [ -e ltsp-jcameron-key.asc ]; then
        wget http://www.webmin.com/jcameron-key.asc || fail "Wgetting jcameron key"
        mv jcameron-key.asc ltsp-jcameron-key.asc
        apt-key add ltsp-jcameron-key.asc || fail "Adding jcameron key"
        apt-get update || fail "Updating"
        apt-get -y install webmin || fail "Installing webmin"
    fi
}

function add_indexes() {
    file="ltsp-indexes.ldif"
    if ! [ -e $file ]; then
        echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: uid eq,pres,sub
olcDbIndex: uidNumber eq,pres
olcDbIndex: gidNumber eq,pres
olcDbIndex: memberUid eq,pres
olcDbIndex: uniqueMember eq,pres" > "$file"
        ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$file"
    fi
}

function logging() {
    #### LOGGING ####
    file="ltsp-logging.ldif"
    if ! [ -e $file ]; then
        echo "dn: cn=config
changetype: modify
add: olcLogLevel
olcLogLevel: stats" > "$file"
        ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$file"
    fi
}

function replication_master_side() {
    provider="ltsp-provider_sync.ldif"
    if ! [ -e $provider ]; then
        echo "# Add indexes to the frontend db.
dn: olcDatabase={1}hdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryCSN eq
-
add: olcDbIndex
olcDbIndex: entryUUID eq

#Load the syncprov and accesslog modules.
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov
-
add: olcModuleLoad
olcModuleLoad: accesslog

# Accesslog database definitions
dn: olcDatabase={2}hdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcHdbConfig
olcDatabase: {2}hdb
olcDbDirectory: /var/lib/ldap/accesslog
olcSuffix: cn=accesslog
olcRootDN: cn=admin,$LDAP_DN
olcDbIndex: default eq
olcDbIndex: entryCSN,objectClass,reqEnd,reqResult,reqStart

# Accesslog db syncprov.
dn: olcOverlay=syncprov,olcDatabase={2}hdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpNoPresent: TRUE
olcSpReloadHint: TRUE

# syncrepl Provider for primary db
dn: olcOverlay=syncprov,olcDatabase={1}hdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpNoPresent: TRUE

# accesslog overlay definitions for primary db
dn: olcOverlay=accesslog,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcAccessLogConfig
olcOverlay: accesslog
olcAccessLogDB: cn=accesslog
olcAccessLogOps: writes
olcAccessLogSuccess: TRUE
# scan the accesslog DB every day, and purge entries older than 7 days
olcAccessLogPurge: 07+00:00 01+00:00" > "$provider"

        file="/etc/apparmor.d/local/usr.sbin.slapd"
        if ! [ $(grep /var/lib/ldap/accesslog $file | wc -l) -gt 0 ]; then
            echo "/var/lib/ldap/accesslog/ r," >> $file
            echo "/var/lib/ldap/accesslog/** rwk," >> $file
            sudo -u openldap mkdir /var/lib/ldap/accesslog
            sudo -u openldap cp /var/lib/ldap/DB_CONFIG /var/lib/ldap/accesslog
            sudo service apparmor reload
        fi

        ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $provider
        service slapd restart
    fi
}

function replication_consumer_side() {
    add2file /etc/hosts "$NETWORK.$DHCP_LDAP01_SERVER ${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN ${APPs[$DHCP_LDAP01_SERVER]}"
    file="ltsp-consumer_sync.ldif"
    if ! [ -e $file ]; then
        echo "dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov

dn: olcDatabase={1}hdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryUUID eq
-
add: olcSyncRepl
olcSyncRepl: rid=$(hostname | tail -c -2) provider=ldap://${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN bindmethod=simple binddn=\"cn=admin,$LDAP_DN\" 
 credentials=$(ask_ldap_pass) searchbase=\"$LDAP_DN\" logbase=\"cn=accesslog\" 
 logfilter=\"(&(objectClass=auditWriteObject)(reqResult=0))\" schemachecking=on 
 type=refreshAndPersist retry=\"60 +\" syncdata=accesslog
-
add: olcUpdateRef
olcUpdateRef: ldap://${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN" > "$file"
        ldapadd -Q -Y EXTERNAL -H ldapi:/// -f "$file"
    fi
}

function confTLS_master_side() {
    ### TLS ####
    # Create a private key for the Certificate Authority:
    cakey="/etc/ssl/private/cakey.pem"
    if ! [ -e $cakey ]; then
        certtool --generate-privkey > $cakey
    fi

    # Create the template/file /etc/ssl/ca.info to define the CA:
    template="/etc/ssl/ca.info"
    if ! [ -e $template ]; then
        echo "cn = $COMPANY
ca
cert_signing_key" > $template
    fi

    # Create the self-signed CA certificate:
    cacert="/etc/ssl/certs/cacert.pem"
    if ! [ -e $cacert ]; then
        certtool --generate-self-signed \
                 --load-privkey $cakey \
                 --template $template \
                 --outfile $cacert
    fi

    # Make a private key for the server:
    servkey="/etc/ssl/private/$(hostname)_slapd_key.pem"
    if ! [ -e $servkey ]; then
        certtool --generate-privkey \
                 --bits 1024 \
                 --outfile $servkey
    fi

    # Create the /etc/ssl/ldap01.info info file containing:
    info="/etc/ssl/$(hostname).info"
    if ! [ -e $info ]; then
        echo "organization = $ORGANIZATION
cn = ${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN
tls_www_server
encryption_key
signing_key
expiration_days = 3650" > $info
    fi

    # Create the server's certificate:
    cert="/etc/ssl/certs/$(hostname)_slapd_cert.pem"
    if ! [ -e $file ]; then
        certtool --generate-certificate \
                 --load-privkey $servkey \
                 --load-ca-certificate $cacert \
                 --load-ca-privkey $cakey \
                 --template $info \
                 --outfile $cert
    fi

    file="/etc/ssl/certinfo.ldif"
    if ! [ -e $file ]; then
        echo "dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: $cacert
-
add: olcTLSCertificateFile
olcTLSCertificateFile: $cert
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $servkey" > $file
        ldapmodify -Y EXTERNAL -H ldapi:/// -f $file
    fi

    adduser openldap ssl-cert
    chgrp ssl-cert $servkey
    chmod g+r $servkey
    chmod o-r $servkey
    service slapd restart

    ### TLS to REPLICATION to ldap02 ###
    ldap="${APPs[$DHCP_LDAP02_SERVER]}"
    ldap_dir="${ldap}-ssl"
    mkdir $ldap_dir
    pushd $ldap_dir
        certtool --generate-privkey \
                 --bits 1024 \
                 --outfile "${ldap}_slapd_key.pem"
        file="${ldap}.info"
        if ! [ -e $file ]; then
            echo "organization = $ORGANIZATION
cn = ${ldap}.$LDAP_DN
tls_www_server
encryption_key
signing_key
expiration_days = 3650" > $file
            certtool --generate-certificate \
                     --load-privkey "${ldap}_slapd_key.pem" \
                     --load-ca-certificate $cacert \
                     --load-ca-privkey $cakey \
                     --template $file \
                     --outfile ${ldap}_slapd_cert.pem
            cp $cacert .
        fi
    popd
    scp -r $ldap_dir root@$NETWORK.$DHCP_LDAP02_SERVER:~
}

function confTLS_consumer_side() {
    ### TLS to REPLICATION from ldap01 ###
    ldap="${APPs[$DHCP_LDAP02_SERVER]}"
    ldap_dir="${ldap}-ssl"
    adduser openldap ssl-cert
    pushd $ldap_dir
        cp ${ldap}_slapd_cert.pem cacert.pem /etc/ssl/certs
        cp ${ldap}_slapd_key.pem /etc/ssl/private
        chgrp ssl-cert /etc/ssl/private/${ldap}_slapd_key.pem
        chmod g+r /etc/ssl/private/${ldap}_slapd_key.pem
        chmod o-r /etc/ssl/private/${ldap}_slapd_key.pem
    popd

    file="/etc/ssl/certinfo.ldif"
    if ! [ -e $file ]; then
        echo "dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/cacert.pem
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ssl/certs/${ldap}_slapd_cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ssl/private/${ldap}_slapd_key.pem" > "$file"
        ldapmodify -Y EXTERNAL -H ldapi:/// -f $file
    fi

    file="consumer_sync_tls.ldif"
    if ! [ -e $file ]; then
        echo "dn: olcDatabase={1}hdb,cn=config
replace: olcSyncRepl
olcSyncRepl: rid=0 provider=ldap://${APPs[$DHCP_LDAP01_SERVER]}.$DOMAIN bindmethod=simple
 binddn=\"cn=admin,$LDAP_DN\" credentials=$(ask_ldap_pass) searchbase=\"$LDAP_DN\"
 logbase=\"cn=accesslog\" logfilter=\"(&(objectClass=auditWriteObject)(reqResult=0))\"
 schemachecking=on type=refreshAndPersist retry=\"60 +\" syncdata=accesslog
 starttls=critical tls_reqcert=demand" > "$file"
        ldapmodify -Y EXTERNAL -H ldapi:/// -f $file
        service slapd restart
    fi
}
