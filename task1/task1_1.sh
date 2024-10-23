#!/bin/bash

name=granatam
group=msp241
prefix="$name"-"$group"
email=a.granat@ispras.ru

openssl genrsa -aes256 -passout pass:"$name" -out "$prefix"-ca.key 4096
openssl req -x509 -new -key "$prefix"-ca.key -passin pass:"$name" \
    -days 1095 -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_1/CN=$name CA/emailAddress=$email" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign" \
    -out "$prefix"-ca.crt

openssl genrsa -aes256 -passout pass:"$name" -out "$prefix"-intr.key 4096
openssl req -new -key "$prefix"-intr.key -passin pass:"$name" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_1/CN=$name Intermediate CA/emailAddress=$email" \
    -addext "basicConstraints=critical,pathlen:0,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign" \
    -out "$prefix"-intr.csr
openssl x509 -req -days 365 -CA "$prefix"-ca.crt -CAkey "$prefix"-ca.key \
    -CAcreateserial -CAserial serial -in "$prefix"-intr.csr \
    -out "$prefix"-intr.crt -passin pass:"$name" -copy_extensions copy

openssl genrsa -passout pass:"$name" -out "$prefix"-basic.key 2048
openssl req -new -key "$prefix"-basic.key -config "$basic_conf" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_1/CN=$name Basic/emailAddress=$email" \
    -addext "basicConstraints=CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,serverAuth,clientAuth" \
    -addext "subjectAltName=DNS:basic.$name.ru,DNS:basic.$name.com" \
    -out "$prefix"-basic.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-basic.csr \
    -out "$prefix"-basic.crt -passin pass:"$name" -copy_extensions copy

zip "$prefix"-p1_1.zip "$prefix"-ca.key "$prefix"-ca.crt "$prefix"-intr.key \
    "$prefix"-intr.crt "$prefix"-basic.key "$prefix"-basic.crt
