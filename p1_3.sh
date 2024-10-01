#!/bin/bash

bash -x ./p1_2.sh

name=granatam
group=msp241
email=a.granat@ispras.ru
dir=$(pwd)

shared_conf=openssl-shared-3.cnf
ocsp_valid_conf=openssl-ocsp-valid.cnf
ocsp_revoked_conf=openssl-ocsp-revoked.cnf
ocsp_resp_conf=openssl-ocsp-resp.cnf
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
OU = $name P1_3
emailAddress = $email
EOF

cat $shared_conf > $ocsp_valid_conf
cat $shared_conf > $ocsp_revoked_conf
cat $shared_conf > $ocsp_resp_conf

cat << EOF >> $ocsp_valid_conf
CN = $name OCSP Valid

[ v3_ocsp_valid_req ]
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:ocsp.valid.$name.ru
crlDistributionPoints   = URI:http://ocsp.$name.ru

[ v3_ocsp_valid_ext ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:ocsp.valid.$name.ru
crlDistributionPoints   = URI:http://ocsp.$name.ru
EOF

cat << EOF >> $ocsp_revoked_conf
CN = $name OCSP Revoked

[ v3_ocsp_revoked_req ]
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:ocsp.revoked.$name.ru
crlDistributionPoints   = URI:http://ocsp.$name.ru

[ v3_ocsp_revoked_ext ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,serverAuth,clientAuth
subjectAltName      = DNS:ocsp.revoked.$name.ru
crlDistributionPoints   = URI:http://ocsp.$name.ru
EOF

cat << EOF >> $ocsp_resp_conf
CN = $name OCSP Responder

[ v3_ocsp_resp_req ]
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = OCSPSigning

[ v3_ocsp_resp_ext ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints    = CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = OCSPSigning
EOF

openssl genrsa -aes256 -passout pass:"$name" -out "$name"-"$group"-ocsp-resp.key 4096
openssl req -new -key "$name"-"$group"-ocsp-resp.key -config "$ocsp_resp_conf" \
    -reqexts v3_ocsp_resp_req -out ocsp-resp.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    ocsp-resp.csr -out "$name"-"$group"-ocsp-resp.crt -passin pass:"$name" \
    -extensions v3_ocsp_resp_ext -extfile "$ocsp_resp_conf"

openssl genrsa -passout pass:"$name" -out "$name"-"$group"-ocsp-valid.key 2048
openssl req -new -key "$name"-"$group"-ocsp-valid.key -config "$ocsp_valid_conf" \
    -reqexts v3_ocsp_valid_req -out ocsp-valid.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    ocsp-valid.csr -out "$name"-"$group"-ocsp-valid.crt -passin pass:"$name" \
    -extensions v3_ocsp_valid_ext -extfile "$ocsp_valid_conf"

openssl genrsa -passout pass:"$name" -out "$name"-"$group"-ocsp-revoked.key 2048
openssl req -new -key "$name"-"$group"-ocsp-revoked.key -config "$ocsp_revoked_conf" \
    -reqexts v3_ocsp_revoked_req -out ocsp-revoked.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    ocsp-revoked.csr -out "$name"-"$group"-ocsp-revoked.crt -passin pass:"$name" \
    -extensions v3_ocsp_revoked_ext -extfile "$ocsp_revoked_conf"

openssl ca -config "$crl_conf" -cert "$name"-"$group"-intr.crt -keyfile \
    "$name"-"$group"-intr.key -revoke "$name"-"$group"-ocsp-revoked.crt \
    -passin pass:"$name"
openssl ca -config "$crl_conf" -cert "$name"-"$group"-intr.crt -keyfile \
    "$name"-"$group"-intr.key -valid "$name"-"$group"-ocsp-valid.crt \
    -passin pass:"$name"

openssl ca -config "$crl_conf" -crlexts crl_ext -cert "$name"-"$group"-intr.crt \
    -keyfile "$name"-"$group"-intr.key -gencrl -out "$name"-"$group".crl \
    -passin pass:"$name"

cat "$name"-"$group"-ca.crt "$name"-"$group"-intr.crt \
    "$name"-"$group"-ocsp-valid.crt "$name"-"$group"-ocsp-revoked.crt > \
    "$name"-"$group"-chain.crt

openssl verify -crl_check -CRLfile "$name"-"$group".crl -CAfile \
    "$name"-"$group"-chain.crt "$name"-"$group"-ocsp-valid.crt
openssl verify -crl_check -CRLfile "$name"-"$group".crl -CAfile \
    "$name"-"$group"-chain.crt "$name"-"$group"-ocsp-revoked.crt

openssl ocsp -url http://ocsp."$name".ru:2560 -index index.txt -CA "$name"-"$group"-chain.crt \
    -rkey "$name"-"$group"-ocsp-resp.key -rsigner "$name"-"$group"-ocsp-resp.crt \
    -passin pass:"$name"

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$name"-"$group"-chain.crt \
    -issuer "$name"-"$group"-intr.crt -cert "$name"-"$group"-ocsp-valid.crt

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$name"-"$group"-chain.crt \
    -issuer "$name"-"$group"-intr.crt -cert "$name"-"$group"-ocsp-revoked.crt
