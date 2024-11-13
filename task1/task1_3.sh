#!/bin/bash

bash -x ./p1_2.sh

# TODO: Doesn't work on MacOS now
BREW_PREFIX=
arch=$1
if [[ $arch = "osx" ]]; then
    BREW_PREFIX=/opt/homebrew
fi

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
cat "$prefix"-ocsp-valid.crt "$prefix"-chain.crt > \
    "$prefix"-ocsp-valid-chain.crt

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
cat "$prefix"-ocsp-revoked.crt "$prefix"-chain.crt > \
    "$prefix"-ocsp-revoked-chain.crt

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
openssl verify -crl_check -CRLfile "$prefix".crl -CAfile "$prefix"-chain.crt \
    "$prefix"-ocsp-revoked.crt

cp "$prefix"-intr.crt "$BREW_PREFIX"/etc/ca-certificates/trust-source/anchors/"$prefix"-intr.crt
trust extract-compat

mkdir -p /var/www

mkdir -p /var/www/"$prefix"-valid
echo Valid! > /var/www/"$prefix"-valid/index.html

mkdir -p /var/www/"$prefix"-revoked
echo Revoked! > /var/www/"$prefix"-revoked/index.html

cp /etc/hosts /etc/hosts_backup
{
    echo 127.0.0.1 ocsp.$name.ru
    echo 127.0.0.1 ocsp.valid.$name.ru
    echo 127.0.0.1 ocsp.revoked.$name.ru
} >> /etc/hosts

cp "$BREW_PREFIX"/etc/nginx/nginx.conf "$BREW_PREFIX"/etc/nginx/nginx.conf.backup

cat << EOF > "$BREW_PREFIX"/etc/nginx/nginx.conf
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    
    server {
        listen       80;
        server_name  localhost;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
    
    server {
        listen       443 ssl;
        server_name  ocsp.valid.$name.ru;
        ssl_certificate      $dir/$prefix-ocsp-valid-chain.crt;
        ssl_certificate_key  $dir/$prefix-ocsp-valid.key;
        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;
        ssl_ocsp on;

        charset UTF-8;
        location / {
            root   /var/www/$prefix-valid;
            index  index.html;
            charset UTF-8;
        }
    }

    server {
        listen       443 ssl;
        server_name  ocsp.revoked.$name.ru;
        ssl_certificate      $dir/$prefix-ocsp-revoked-chain.crt;
        ssl_certificate_key  $dir/$prefix-ocsp-revoked.key;
        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;
        ssl_ocsp on;
        charset UTF-8;
        location / {
            root   /var/www/$prefix-revoked;
            index  index.html;
            charset UTF-8;
        }
    }
}
EOF

nginx -s reload

openssl ocsp -port 2560 -index index.txt -CA "$prefix"-chain.crt \
    -rkey "$prefix"-ocsp-resp.key -rsigner "$prefix"-ocsp-resp.crt \
    -passin pass:"$name" &

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$prefix"-chain.crt \
    -issuer "$prefix"-intr.crt -cert "$prefix"-ocsp-valid.crt

openssl ocsp -url http://ocsp."$name".ru:2560 -CAfile "$prefix"-chain.crt \
    -issuer "$prefix"-intr.crt -cert "$prefix"-ocsp-revoked.crt

read  -n 1 -s -p "Waiting for Wireshark (valid)"
export SSLKEYLOFILE=$prefix-ocsp-valid.log
firefox https://ocsp.valid.$name.ru

read  -n 1 -s -p "Waiting for Wireshark (revoked)"
export SSLKEYLOFILE=$prefix-ocsp-revoked.log
firefox https://ocsp.revoked.$name.ru

rm -rf /var/www/$prefix-valid /var/www/$prefix-revoked

mv /etc/hosts_backup /etc/hosts
mv "$BREW_PREFIX"/etc/nginx/nginx.conf.backup "$BREW_PREFIX"/etc/nginx/nginx.conf

rm "$BREW_PREFIX"/etc/ca-certificates/trust-source/anchors/"$prefix"-intr.crt
trust extract-compat
