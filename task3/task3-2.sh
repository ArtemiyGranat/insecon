#!/bin/bash

name=granatam
group=msp241
prefix="$name-$group"
email=a.granat@ispras.ru

task1="$(dirname "$0")/../task1"
ca_crt="$prefix-ca.crt"

proxy="http://127.0.0.1:3128"

# Use solution for 1.1 to get the root CA certificate
bash -x "$task1/task1_1.sh"

# Generate Squid CA certificate
openssl genrsa -out "$prefix"-bump.key 4096
openssl req -new -key "$prefix"-bump.key -passin pass:"$name" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=$name/OU=$name P3_2/CN=$name Squid CA/emailAddress=$email" \
    -addext "basicConstraints=critical,pathlen:0,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign" \
    -out "$prefix"-bump.csr
openssl x509 -req -days 365 -CA "$prefix"-ca.crt -CAkey "$prefix"-ca.key \
    -CAcreateserial -CAserial serial -in "$prefix"-bump.csr \
    -out "$prefix"-bump.crt -passin pass:"$name" -copy_extensions copy

# Generate certificates chain for Squid
cat "$prefix"-bump.crt "$prefix"-ca.crt > "$prefix"-chain.crt

# Make sure that needed SSLKEYLOG files will be empty
rm "$prefix"-acl.log
rm "$prefix"-bump.log

cat << EOF > "$prefix-acl.conf"
acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
acl localnet src fc00::/7       	# RFC 4193 local private network range
acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http

http_access deny !Safe_ports

http_access allow localhost manager
http_access deny manager

http_access allow localhost
http_access deny to_localhost

http_access allow localnet

acl identme ssl::server_name ident.me
acl httpbin ssl::server_name httpbin.org

http_access allow identme
http_access allow httpbin

http_access deny all

http_port 3128 ssl-bump dynamic_cert_mem_cache_size=4MB cert=/squid/$prefix-chain.crt key=/squid/$prefix-bump.key generate-host-certificates=on
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/spool/squid/ssl_db -M 4MB

acl step1 at_step SslBump1
ssl_bump peek step1
ssl_bump splice httpbin
ssl_bump terminate all

refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
EOF

# Start squid container
docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10 \
    squid -f /squid/"$prefix"-acl.conf -NYC

# shellcheck disable=SC2162
read -p "Open Wireshark, start capturing traffic on the any interface and \
press any key"

# Send queries
SSLKEYLOGFILE="$prefix"-acl.log curl --tlsv1.2 --tls-max 1.2 -v --proxy $proxy https://ident.me
SSLKEYLOGFILE="$prefix"-acl.log curl --tlsv1.2 --tls-max 1.2 -v --proxy $proxy -k https://httpbin.org/get?bio="$name"

read -r -p "Save trace to $prefix-acl.pcapng, then press Enter"

docker rm "$(docker stop squid)"

cat << EOF > "$prefix-bump.conf"
acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
acl localnet src fc00::/7       	# RFC 4193 local private network range
acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http

http_access deny !Safe_ports

http_access allow localhost manager
http_access deny manager

http_access allow localhost
http_access deny to_localhost

http_access allow localnet

http_access deny all

http_port 3128 ssl-bump dynamic_cert_mem_cache_size=4MB cert=/squid/$prefix-chain.crt key=/squid/$prefix-bump.key generate-host-certificates=on
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/spool/squid/ssl_db -M 4MB

acl httpbin ssl::server_name httpbin.org
http_access allow httpbin
ssl_bump bump httpbin
sslproxy_cert_error allow httpbin
ssl_bump stare httpbin

refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
EOF

docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10 \
    squid -f /squid/$prefix-bump.conf -NYC

read -r -p "Start capturing traffic on the any interface and press Enter"

SSLKEYLOGFILE="$prefix"-bump.log curl --tlsv1.2 --tls-max 1.2 -v --proxy "$proxy" -k https://httpbin.org/get?bio="$name"

read -r -p "Save trace to $prefix-bump.pcapng, then press Enter"

docker rm "$(docker stop squid)"

zip "$prefix"-p3_2.zip "$prefix"-acl.pcapng "$prefix"-acl.log \
    "$prefix"-acl.conf "$prefix"-bump.pcapng "$prefix"-bump.log \
    "$prefix"-bump.conf "$prefix"-bump.crt "$prefix"-bump.key \
    "$ca_crt"
