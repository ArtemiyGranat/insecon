#!/bin/bash

bash -x ./p1_1.sh

# Credentials
name=granatam
group=msp241
prefix="$name"-"$group"
email=a.granat@ispras.ru
dir=$(pwd)

# CRL config
crl_conf=crl.cnf
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

crl = $dir/$prefix.crl # The current CRL
private_key	= $dir/$prefix-ca.key # The private key

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

# These files must exist for CRL gen
touch "$dir/index.txt"
echo 10 > "$dir/crlnumber"

# Generate CRL valid certificate
openssl genrsa -passout pass:"$name" -out "$prefix"-crl-valid.key 2048
openssl req -new -key "$prefix"-crl-valid.key -passin pass:"$name" \
     -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_2/CN=$name CRL Valid/emailAddress=$email" \
     -addext "basicConstraints=CA:FALSE" \
     -addext "keyUsage=critical,digitalSignature" \
     -addext "extendedKeyUsage=critical,serverAuth,clientAuth" \
     -addext "subjectAltName=DNS:crl.valid.$name.ru" \
     -addext "crlDistributionPoints=URI:http://crl.$name.ru" \
     -out "$prefix"-crl-valid.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-crl-valid.csr \
    -out "$prefix"-crl-valid.crt -passin pass:"$name" -copy_extensions copy

# Generate CRL Revoked certificate
openssl genrsa -passout pass:"$name" -out "$prefix"-crl-revoked.key 2048
openssl req -new -key "$prefix"-crl-valid.key -passin pass:"$name" \
     -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_2/CN=$name CRL Revoked/emailAddress=$email" \
     -addext "basicConstraints=CA:FALSE" \
     -addext "keyUsage=critical,digitalSignature" \
     -addext "extendedKeyUsage=critical,serverAuth,clientAuth" \
     -addext "subjectAltName=DNS:crl.revoked.$name.ru" \
     -addext "crlDistributionPoints=URI:http://crl.$name.ru" \
     -out "$prefix"-crl-revoked.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-crl-revoked.csr \
    -out "$prefix"-crl-revoked.crt -passin pass:"$name" -copy_extensions copy

# Revoke and validate certificates
openssl ca -config "$crl_conf" -cert "$prefix"-intr.crt -keyfile \
    "$prefix"-intr.key -revoke "$prefix"-crl-revoked.crt -passin pass:"$name"
openssl ca -config "$crl_conf" -cert "$prefix"-intr.crt -keyfile \
    "$prefix"-intr.key -valid "$prefix"-crl-valid.crt -passin pass:"$name"

# Generate CRL
openssl ca -config "$crl_conf" -crlexts crl_ext -cert "$prefix"-intr.crt \
    -keyfile "$prefix"-intr.key -gencrl -out "$prefix".crl -passin pass:"$name"

# Generate certificates chain
cat "$prefix"-ca.crt "$prefix"-intr.crt > "$prefix"-chain.crt

# Try to verify certificates
openssl verify -crl_check -CRLfile "$prefix".crl -CAfile "$prefix"-chain.crt \
    "$prefix"-crl-valid.crt
openssl verify -crl_check -CRLfile "$prefix".crl -CAfile "$prefix"-chain.crt \
    "$prefix"-crl-revoked.crt

# Archive needed files
rm "$prefix"-p1_2.zip
zip "$prefix"-p1_2.zip "$prefix"-crl-valid.key \
    "$prefix"-crl-valid.crt "$prefix"-crl-revoked.key \
    "$prefix"-crl-revoked.crt "$prefix".crl \
    "$prefix"-chain.crt
