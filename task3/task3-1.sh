#!/bin/bash

name=granatam
group=msp241
prefix="$name"-"$group"

proxy="http://127.0.0.1:3128"
squid_conf=squid.conf

cat << EOF > "$squid_conf"
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

acl identme dstdomain .ident.me
http_access deny identme

http_access allow localnet

http_access deny all

http_port 3128

refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
EOF

docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10 \
    squid -f /squid/squid.conf -NYC

# shellcheck disable=SC2162
read -p "Open Wireshark, start capturing traffic on the any interface and \
press Enter"

curl -v --proxy $proxy ident.me --user-agent $name
curl -v --proxy $proxy httpbin.org/get?bio=$name

read -r -p "Save trace to $prefix-acl.pcapng, then press Enter"

docker rm "$(docker stop squid)"

cat << EOF > $squid_conf
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

request_header_access User-Agent deny all
request_header_replace User-Agent $name

http_access allow localnet

http_access deny all

http_port 3128

refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
EOF

docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10 \
    squid -f /squid/$squid_conf -NYC

read -r -p "Start capturing traffic on the any interface and press Enter"

curl --proxy $proxy httpbin.org/ip

read -r -p "Save trace to $prefix-ua.pcapng, then press Enter"

docker rm "$(docker stop squid)"

rm $squid_conf

zip "$prefix"-p3_1.zip "$prefix"-ua.pcapng "$prefix"-acl.pcapng
