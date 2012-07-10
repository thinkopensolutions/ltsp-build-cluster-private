#!/bin/bash

# LDAP Server Provider (HA REPLICATION)
# Upstream documentation https://help.ubuntu.com/12.04/serverguide/openldap-server.html

. install-ldap-include.sh

# Install Webmin
if ! [ $(cat /etc/apt/sources.list | grep "webmin.mirror" | wc -l) -gt 0 ]; then
    echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list || fail "Adding to sources"
    echo "deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib" >> /etc/apt/sources.list || fail "Adding to sources"
    pushd /tmp
    wget http://www.webmin.com/jcameron-key.asc || fail "Wgetting jcameron key"
    apt-key add jcameron-key.asc || fail "Adding jcameron key"
    apt-get update || fail "Updating"
    apt-get -y install webmin || fail "Installing webmin"
    popd
fi

#### ADD GROUPS ####
file="add_content.ldif"
if ! [ -e $file ]; then
    echo "dn: ou=People,$LDAP_DN
objectClass: organizationalUnit
ou: People

dn: ou=Groups,$LDAP_DN
objectClass: organizationalUnit
ou: Groups

dn: cn=miners,ou=Groups,$LDAP_DN
objectClass: posixGroup
cn: miners
gidNumber: 5000

dn: uid=john,ou=People,$LDAP_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: john
sn: Doe
givenName: John
cn: John Doe
displayName: John Doe
uidNumber: 10000
gidNumber: 5000
userPassword: johnldap
gecos: John Doe
loginShell: /bin/bash
homeDirectory: /home/john" > "$file"
    ldapadd -x -D cn=admin,$LDAP_DN -W -f "$file"
    test_cmd="ldapsearch -x -LLL -b $LDAP_DN 'uid=john' cn gidNumber"
    echo -n "TEST: $test_cmd"; read x
fi

#### REPLICATION ####
provider="provider_sync.ldif"
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
    if ! [ $(cat $file | grep /var/lib/ldap/accesslog | wc -l) -gt 0 ]; then
        echo "/var/lib/ldap/accesslog/ r," >> $file
        echo "/var/lib/ldap/accesslog/** rwk," >> $file
        sudo -u openldap mkdir /var/lib/ldap/accesslog
        sudo -u openldap cp /var/lib/ldap/DB_CONFIG /var/lib/ldap/accesslog
        sudo service apparmor reload
    fi
        
    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $provider
    service slapd restart
fi

# LDAP Client
if ! [ $(cat /etc/hosts | grep ${APPs[$LDAP]} | wc -l) -gt 0 ]; then
    echo "$NETWORK.$LDAP ${APPs[$LDAP]}.$DOMAIN  ${APPs[$LDAP]}" >> /etc/hosts || fail "Adding ${APPs[$LDAP]} to hosts"
    echo "$NETWORK.25 ldap02.$DOMAIN  ldap02" >> /etc/hosts || fail "Adding ldap02 to hosts"
fi
apt-get -y install libnss-ldap || fail "Installing ldap client"
dpkg-reconfigure ldap-auth-config
auth-client-config -t nss -p lac_ldap
pam-auth-update

exit

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
cn = ${APPs[$LDAP]}.$DOMAIN
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
ldap="ldap02"
ldap_dir="${ldap}-ssl"
mkdir $ldap_dir
pushd $ldap_dir
    certtool --generate-privkey \
             --bits 1024 \
             --outfile "${ldap}_slapd_key.pem"
    file="${ldap}.info"
    if ! [ -e $file ]; then
        echo "organization = $ORGANIZATION
cn = ldap02.$LDAP_DN
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
scp -r $ldap_dir root@$NETWORK.25:~

echo "OK ENTER FOR REBOOT"; read x; reboot

