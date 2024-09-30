#!/bin/bash

name=granatam
group=msp241
email=a.granat@ispras.ru

shared_conf=openssl-shared.cnf
ca_conf=openssl-ca.cnf
intr_conf=openssl-intr.cnf
basic_conf=openssl-basic.cnf

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
OU = $name P1_1
emailAddress = $email
EOF

cat $shared_conf > $ca_conf
cat $shared_conf > $intr_conf
cat $shared_conf > $basic_conf

cat << EOF >> $ca_conf
CN = $name CA

[ v3_ca_req ]
basicConstraints       = critical,CA:true
keyUsage               = critical,digitalSignature,keyCertSign,cRLSign

[ v3_ca_ext ]
basicConstraints       = critical,CA:true
keyUsage               = critical,digitalSignature,keyCertSign,cRLSign
EOF

cat << EOF >> $intr_conf
CN = $name Intermediate CA

[ v3_intr_req ]
basicConstraints       = critical,pathlen:0,CA:true
keyUsage               = critical,digitalSignature,keyCertSign,cRLSign

[ v3_intr_ext ]
basicConstraints       = critical,pathlen:0,CA:true
keyUsage               = critical,digitalSignature,keyCertSign,cRLSign
EOF

cat << EOF >> $basic_conf
CN = $name Basic

[ v3_basic_req ]
basicConstraints       = CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,serverAuth,clientAuth
subjectAltName         = DNS:basic.$name.ru,DNS:basic.$name.com

[ v3_basic_ext ]
basicConstraints       = CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,serverAuth,clientAuth
subjectAltName         = DNS:basic.$name.ru,DNS:basic.$name.com
EOF

# Generate RSA 4096 bit key and CA sertificate
openssl genrsa -aes256 -passout pass:"$name" -out "$name"-"$group"-ca.key 4096
openssl req -x509 -config "$ca_conf" -passin pass:"$name" -new -key \
    "$name"-"$group"-ca.key -days 1095 -out "$name"-"$group"-ca.crt \
    -reqexts v3_ca_req -extensions v3_ca_ext

# Generate RSA 4096 bit key and certificate signed by CA certificate
openssl genrsa -aes256 -passout pass:"$name" -out "$name"-"$group"-intr.key 4096
openssl req -config "$intr_conf" -passin pass:"$name" -new -key \
    "$name"-"$group"-intr.key -out "$name"-"$group"-intr.csr -reqexts v3_intr_req
openssl x509 -req -days 365 -CA "$name"-"$group"-ca.crt -CAkey \
    "$name"-"$group"-ca.key -CAcreateserial -CAserial serial -in \
    "$name"-"$group"-intr.csr -out "$name"-"$group"-intr.crt \
    -passin pass:"$name" -extensions v3_intr_ext -extfile "$intr_conf"

# Generate RSA 2048 bit key and certificate signed by intermediate certificate
openssl genrsa -passout pass:"$name" -out "$name"-"$group"-basic.key 2048
openssl req -new -key "$name"-"$group"-basic.key -config "$basic_conf" \
    -reqexts v3_basic_req -out basic.csr -passin pass:"$name"
openssl x509 -req -days 90 -CA "$name"-"$group"-intr.crt -CAkey \
    "$name"-"$group"-intr.key -CAcreateserial -CAserial serial -in \
    basic.csr -out "$name"-"$group"-basic.crt -passin pass:"$name" \
    -extensions v3_basic_ext -extfile "$basic_conf"

zip "$name"-"$group"-p1_1.zip "$name"-"$group"-ca.key "$name"-"$group"-ca.crt \
    "$name"-"$group"-intr.key "$name"-"$group"-intr.crt \
    "$name"-"$group"-basic.key "$name"-"$group"-basic.crt
