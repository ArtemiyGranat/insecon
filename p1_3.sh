#!/bin/bash

bash -x ./p1_2.sh

name=granatam
group=msp241
email=a.granat@ispras.ru
prefix="$name"-"$group"
dir=$(pwd)

crl_conf=crl.cnf

openssl genrsa -aes256 -passout pass:"$name" -out "$prefix"-ocsp-resp.key 4096
openssl req -new -key "$prefix"-ocsp-resp.key -passin pass:"$name" \
     -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_3/CN=$name OCSP Responder/emailAddress=$email" \
     -addext "basicConstraints=CA:FALSE" \
     -addext "keyUsage=critical,digitalSignature" \
     -addext "extendedKeyUsage=OCSPSigning" \
     -out "$prefix"-ocsp-resp.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-ocsp-resp.csr \
    -out "$prefix"-ocsp-resp.crt -passin pass:"$name" -copy_extensions copy

openssl genrsa -passout pass:"$name" -out "$prefix"-ocsp-valid.key 2048
openssl req -new -key "$prefix"-ocsp-valid.key -passin pass:"$name" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_3/CN=$name OCSP Valid/emailAddress=$email" \
    -addext "basicConstraints=CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,serverAuth,clientAuth" \
    -addext "subjectAltName=DNS:ocsp.valid.$name.ru" \
    -addext "authorityInfoAccess=OCSP;URI:http://ocsp.$name.ru:2560/" \
    -out "$prefix"-ocsp-valid.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-ocsp-valid.csr \
    -out "$prefix"-ocsp-valid.crt -passin pass:"$name" -copy_extensions copy

openssl genrsa -passout pass:"$name" -out "$prefix"-ocsp-revoked.key 2048
openssl req -new -key "$prefix"-ocsp-revoked.key -passin pass:"$name" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P1_3/CN=$name OCSP Revoked/emailAddress=$email" \
    -addext "basicConstraints=CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,serverAuth,clientAuth" \
    -addext "subjectAltName=DNS:ocsp.revoked.$name.ru" \
    -addext "authorityInfoAccess=OCSP;URI:http://ocsp.$name.ru:2560/" \
    -out "$prefix"-ocsp-revoked.csr
openssl x509 -req -days 90 -CA "$prefix"-intr.crt -CAkey "$prefix"-intr.key \
    -CAcreateserial -CAserial serial -in "$prefix"-ocsp-revoked.csr \
    -out "$prefix"-ocsp-revoked.crt -passin pass:"$name" -copy_extensions copy

openssl ca -config "$crl_conf" -cert "$prefix"-intr.crt \
    -keyfile "$prefix"-intr.key -revoke "$prefix"-ocsp-revoked.crt \
    -passin pass:"$name"
openssl ca -config "$crl_conf" -cert "$prefix"-intr.crt \
    -keyfile "$prefix"-intr.key -valid "$prefix"-ocsp-valid.crt \
    -passin pass:"$name"

openssl ca -config "$crl_conf" -crlexts crl_ext -cert "$prefix"-intr.crt \
    -keyfile "$prefix"-intr.key -gencrl -out "$prefix".crl -passin pass:"$name"

openssl verify -crl_check -CRLfile "$prefix".crl -CAfile "$prefix"-chain.crt \
    "$prefix"-ocsp-valid.crt
openssl verify -crl_check -CRLfile "$preifx".crl -CAfile "$prefix"-chain.crt \
    "$prefix"-ocsp-revoked.crt

openssl ocsp -url http://ocsp."$name".ru:2560 -index index.txt \
    -CA "$prefix"-chain.crt -rkey "$prefix"-ocsp-resp.key \
    -rsigner "$prefix"-ocsp-resp.crt -passin pass:"$name"

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$prefix"-chain.crt \
    -issuer "$prefix"-intr.crt -cert "$prefix"-ocsp-valid.crt

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$prefix"-chain.crt \
    -issuer "$prefix"-intr.crt -cert "$prefix"-ocsp-revoked.crt
