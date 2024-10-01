#!/bin/bash

bash -x ./p1_1.sh

name=granatam
group=msp241
email=a.granat@ispras.ru
dir=$(pwd)

shared_conf=openssl-shared-2.cnf
crl_valid_conf=openssl-crl-valid.cnf
crl_revoked_conf=openssl-crl-revoked.cnf
crl_conf=openssl-crl.cnf

# Generate openssl-shared.cnf
cat << EOF > $shared_conf
[ req ]
prompt = no
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C = RU
ST = Moscow
L = Moscow
O = $name
OU = $name P1_2
emailAddress = $email
EOF

cat $shared_conf > $crl_valid_conf
cat $shared_conf > $crl_revoked_conf

cat << EOF >> $crl_valid_conf
CN = $name CRL Valid

[ v3_crl_valid_req ]
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:crl.valid.$name.ru
crlDistributionPoints   = URI:http://crl.$name.ru

[ v3_crl_valid_ext ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:crl.valid.$name.ru
crlDistributionPoints   = URI:http://crl.$name.ru
EOF

cat << EOF >> $crl_revoked_conf
CN = $name CRL Revoked

[ v3_crl_revoked_req ]
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:crl.revoked.$name.ru
crlDistributionPoints   = URI:http://crl.$name.ru

[ v3_crl_revoked_ext ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:crl.revoked.$name.ru
crlDistributionPoints   = URI:http://crl.$name.ru
EOF

cat << EOF > $crl_conf
[ ca ]
default_ca = CA_default # The default ca section

[ CA_default ]
dir = $dir # Where everything is kept
certs = $dir/certs # Where the issued certs are kept
crl_dir = $dir/crl # Where the issued crl are kept
database = $dir/index.txt # database index file.
unique_subject = no # Set to 'no' to allow creation of
                    # several certs with same subject.
new_certs_dir = $dir/newcerts # default place for new certs.

certificate = $dir/cacert.pem # The CA certificate
serial = $dir/serial # The current serial number
crlnumber = $dir/crlnumber # the current crl number

crl = $dir/$name-$group.crl # The current CRL
private_key	= $dir/$name-$group-ca.key # The private key

x509_extensions = usr_cert # The extensions to add to the cert

# Comment out the following two lines for the "traditional"
# (and highly broken) format.
name_opt = ca_default # Subject Name options
cert_opt = ca_default # Certificate field options

default_days = 365 # how long to certify for
default_crl_days = 30 # how long before next CRL
default_md = default # use public key default MD
preserve = no # keep passed DN ordering

# A few difference way of specifying how similar the request should look
# For type CA, the listed attributes must be the same, and the optional
# and supplied fields are just that :-)
policy = policy_match

# For the CA policy
[ policy_match ]
countryName = match
stateOrProvinceName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ crl_ext ]
authorityKeyIdentifier=keyid,issuer
EOF

touch index.txt
echo 10 > crlnumber

openssl genrsa -passout pass:"$name" -out "$name"-"$group"-crl-valid.key 2048
openssl req -new -key "$name"-"$group"-crl-valid.key -config "$crl_valid_conf" \
    -reqexts v3_crl_valid_req -out crl-valid.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    crl-valid.csr -out "$name"-"$group"-crl-valid.crt -passin pass:"$name" \
    -extensions v3_crl_valid_ext -extfile "$crl_valid_conf"

openssl genrsa -passout pass:"$name" -out "$name"-"$group"-crl-revoked.key 2048
openssl req -new -key "$name"-"$group"-crl-revoked.key -config "$crl_revoked_conf" \
    -reqexts v3_crl_revoked_req -out crl-revoked.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    crl-revoked.csr -out "$name"-"$group"-crl-revoked.crt -passin pass:"$name" \
    -extensions v3_crl_revoked_ext -extfile "$crl_revoked_conf"

openssl ca -config "$crl_conf" -cert "$name"-"$group"-intr.crt -keyfile \
    "$name"-"$group"-intr.key -revoke "$name"-"$group"-crl-revoked.crt \
    -passin pass:"$name"
openssl ca -config "$crl_conf" -cert "$name"-"$group"-intr.crt -keyfile \
    "$name"-"$group"-intr.key -valid "$name"-"$group"-crl-valid.crt \
    -passin pass:"$name"

openssl ca -config "$crl_conf" -crlexts crl_ext -cert "$name"-"$group"-intr.crt \
    -keyfile "$name"-"$group"-intr.key -gencrl -out "$name"-"$group".crl \
    -passin pass:"$name"

cat "$name"-"$group"-ca.crt "$name"-"$group"-intr.crt \
    "$name"-"$group"-crl-valid.crt "$name"-"$group"-crl-revoked.crt > \
    "$name"-"$group"-chain.crt

openssl verify -crl_check -CRLfile "$name"-"$group".crl -CAfile \
    "$name"-"$group"-chain.crt "$name"-"$group"-crl-valid.crt
openssl verify -crl_check -CRLfile "$name"-"$group".crl -CAfile \
    "$name"-"$group"-chain.crt "$name"-"$group"-crl-revoked.crt

rm "$name"-"$group"-p1_2.zip

zip "$name"-"$group"-p1_2.zip "$name"-"$group"-crl-valid.key \
    "$name"-"$group"-crl-valid.crt "$name"-"$group"-crl-revoked.key \
    "$name"-"$group"-crl-revoked.crt "$name"-"$group".crl \
    "$name"-"$group"-chain.crt
