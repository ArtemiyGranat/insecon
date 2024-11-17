#!/bin/bash

name=granatam
group=msp241
prefix="$name"-"$group"

proxy=127.0.0.1:3128
squid_conf=squid.conf

# TODO: Add config
cat << EOF > $squid_conf
EOF

docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10

read -n 1 -s -p "Open Wireshark, start capturing traffic on the any interface and press any key"

curl --proxy $proxy ident.me --user-agent $name
curl --proxy $proxy httpbin.org/get?bio=$name --user-agent $name

read -n 1 -s -p "Save trace to $prefix-acl.pcapng, then press any key"

docker rm $(docker stop squid)

read -n 1 -s -p "Start capturing traffic on the any interface and press any key"

# TODO: Add config
cat << EOF > $squid_conf
EOF

docker run -d --name squid -v .:/squid -p 3128:3128 -it yutony/squid:4.10 squid -f /squid/$squid_conf -NYC

curl --proxy $proxy httpbin.org/ip

read -n 1 -s -p "Save trace to $prefix-ua.pcapng, then press any key"

docker rm $(docker stop squid)

rm $squid_conf

zip "$prefix"-p3_1.zip "$prefix"-ua.pcapng "$prefix"-acl.pcapng
