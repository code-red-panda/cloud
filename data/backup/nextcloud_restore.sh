#!/bin/bash

TS=$1

cd /opt/cloud

/usr/local/bin/docker-compose down

ls /var/lib/docker/volumes/ | grep -v cloud_percona_datadir | xargs -iX rm -rf /var/lib/docker/volumes/X

tar xzf /backups/$TS/nextcloud_backup.tar.gz -C /

/usr/local/bin/docker-compose up -d

IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' percona-server)

sed -i 's/host=.*/host='$IP'/' /root/.my.cnf

myloader --directory=/backups/$TS/mydumper --overwrite-tables --enable-binlog --queries-per-transaction=10 --threads=2 --verbose 3

docker exec -u www-data nextcloud php occ maintenance:mode --off
