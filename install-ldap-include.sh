#!/bin/bash

# LDAP Server Consumer (HA REPLICATION)
# Upstream documentation https://help.ubuntu.com/12.04/serverguide/openldap-server.html

. ltsp-include.sh

apt-get -y install slapd ldap-utils gnutls-bin ssl-cert || fail "Installing LDAP"

#### ADD INDEX ####
file="uid_index.ldif"
if ! [ -e $file ]; then
    echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: uid eq,pres,sub" > "$file"
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$file"
    test_cmd="ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=config '(olcDatabase={1}hdb)' olcDbIndex"
    echo -n "TEST: $test_cmd"; read x
fi

#### ADD SCHEMA ####
file="schema_convert.conf"
if ! [ -e $file ]; then
    echo "include /etc/ldap/schema/core.schema
include /etc/ldap/schema/collective.schema
include /etc/ldap/schema/corba.schema
include /etc/ldap/schema/cosine.schema
include /etc/ldap/schema/duaconf.schema
include /etc/ldap/schema/dyngroup.schema
include /etc/ldap/schema/inetorgperson.schema
include /etc/ldap/schema/java.schema
include /etc/ldap/schema/misc.schema
include /etc/ldap/schema/nis.schema
include /etc/ldap/schema/openldap.schema
include /etc/ldap/schema/ppolicy.schema
include /etc/ldap/schema/ldapns.schema
include /etc/ldap/schema/pmi.schema" > "$file"
    ldif_dir="ldif_output"
    mkdir "$ldif_dir"
    schema_index=$(slapcat -f "$file" -F "$ldif_dir" -n 0 | grep corba,cn=schema | cut -b 5- )
    corba_file="corba.ldif"
    slapcat -f "$file" -F "$ldif_dir" -n0 -H ldap:///"$schema_index" -l cn="$corba_file"
    sed -i "s/{.}corba/corba/g" cn\="$corba_file"
    sed -i "s/structuralObjectClass:.*$//g" cn\="$corba_file"
    sed -i "s/entryUUID:.*$//g" cn\="$corba_file"
    sed -i "s/creatorsName:.*$//g" cn\="$corba_file"
    sed -i "s/createTimestamp:.*$//g" cn\="$corba_file"
    sed -i "s/entryCSN:.*$//g" cn\="$corba_file"
    sed -i "s/modifiersName:.*$//g" cn\="$corba_file"
    sed -i "s/modifyTimestamp:.*$//g" cn\="$corba_file"
    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f cn\="$corba_file"
    test_cmd="ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=schema,cn=config dn"
    echo -n "TEST: $test_cmd"; read x
fi

#### LOGGING ####
file="logging.ldif"
if ! [ -e $file ]; then
    echo "dn: cn=config
changetype: modify
add: olcLogLevel
olcLogLevel: stats" > "$file"
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$file"
fi

