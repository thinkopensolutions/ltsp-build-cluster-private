#!/bin/bash

# LDAP Server Consumer (HA REPLICATION)
# Upstream documentation https://help.ubuntu.com/12.04/serverguide/openldap-server.html

. install-ldap-include.sh

#### REPLICATION ####
if ! [ $(cat /etc/hosts | grep ${APPs[$LDAP]} | wc -l) -gt 0 ]; then
    echo "$NETWORK.$LDAP ${APPs[$LDAP]}.$DOMAIN  ${APPs[$LDAP]}" >> /etc/hosts || fail "Adding ${APPs[$LDAP]} to hosts"
fi

file="consumer_sync.ldif"
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
olcSyncRepl: rid=$(hostname | tail -c -2) provider=ldap://${APPs[$LDAP]}.$DOMAIN bindmethod=simple binddn=\"cn=admin,$LDAP_DN\" 
 credentials=Thinkopen120! searchbase=\"$LDAP_DN\" logbase="cn=accesslog" 
 logfilter=\"(&(objectClass=auditWriteObject)(reqResult=0))\" schemachecking=on 
 type=refreshAndPersist retry=\"60 +\" syncdata=accesslog
-
add: olcUpdateRef
olcUpdateRef: ldap://${APPs[$LDAP]}.$DOMAIN" > "$file"
    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f "$file"
fi

exit 

### TLS to REPLICATION from ldap01 ###
ldap="ldap02"
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
olcSyncRepl: rid=0 provider=ldap://${APPs[$LDAP]}.$DOMAIN bindmethod=simple
 binddn=\"cn=admin,$LDAP_DN\" credentials=Thinkopen120! searchbase=\"$LDAP_DN\"
 logbase=\"cn=accesslog\" logfilter=\"(&(objectClass=auditWriteObject)(reqResult=0))\"
 schemachecking=on type=refreshAndPersist retry=\"60 +\" syncdata=accesslog
 starttls=critical tls_reqcert=demand" > "$file"
    ldapmodify -Y EXTERNAL -H ldapi:/// -f $file
    service slapd restart
fi

echo "OK ENTER FOR REBOOT"; read x; reboot

